//
//  RootViewController.swift
//  ShareSpace
//
//  Created by Bienbenido Angeles on 6/3/20.
//  Copyright © 2020 Bienbenido Angeles. All rights reserved.
//

import UIKit
import MapKit

class RootViewController: NavBarViewController {
    private let locationSession = CoreLocationSession.shared.locationManager
    
    let rootView = RootView()
    
    private lazy var mapView = rootView.mapView
    
    enum CardState {
        case expanded
        case collapsed
    }
    
    var cardVC: CardViewController!
    var visualEffectView: UIVisualEffectView!
    
    let cardHeight:CGFloat = 600
    let cardHandleAreaHeight: CGFloat = 65
    
    var cardVisible = false
    
    weak var delegate: SearchPostDelegate?
    
    var nextState: CardState {
        return cardVisible ? .collapsed : .expanded
    }
    
    var runningAnimations = [UIViewPropertyAnimator]()
    var animationProgressWhenInterrupted: CGFloat = 0
    
    lazy var tabBarheight:CGFloat = self.tabBarController!.tabBar.frame.size.height
    lazy var navBarHeight:CGFloat = self.navigationController!.navigationBar.frame.size.height
    lazy var searchBarHeight:CGFloat = self.rootView.searchBarView.frame.size.height
    lazy var totalHeight = tabBarheight + navBarHeight + searchBarHeight
    
    private lazy var topRightCoor = rootView.mapView.convert(CGPoint(x: rootView.mapView.bounds.width, y: 0), toCoordinateFrom: rootView.mapView)
    private lazy var bottomLeftCoor = rootView.mapView.convert(CGPoint(x: 0, y: rootView.mapView.bounds.height), toCoordinateFrom: rootView.mapView)
    
    override func loadView() {
        super.loadView()
        view = rootView
        view.backgroundColor = .systemBackground
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        delegatesAndDataSources()
        addTargets()
        setupCard()
        setupMap()
        addNavButtons()
        setupGestures()
    }
    
    private func delegatesAndDataSources(){
        rootView.mapView.delegate = self
    }
    
    private func setupGestures(){
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(searchLabelTapped(_:)))
        rootView.searchLabel.addGestureRecognizer(tapGesture)
    }
    
    private func addTargets(){
        rootView.dateTimeButton.addTarget(self, action: #selector(dateTimeButtonPressed), for: .touchUpInside)
        rootView.searchByMapViewButton.addTarget(self, action: #selector(mapViewButtonPressed), for: .touchUpInside)
    }
    
    private func addNavButtons(){
        let barButtonItem = UIBarButtonItem(image: UIImage(systemName: "calendar.circle"), style: .plain, target: self, action: #selector(calenderButtonPressed))
        navigationItem.rightBarButtonItems?.append(barButtonItem)
    }
    
    @objc private func searchLabelTapped(_ recognizer: UITapGestureRecognizer){
        let searchCompletor =  CoreLocationSession.shared.searchCompletor
        let searchResultsVC = SearchResultsViewController(searchCompletor: searchCompletor)
        searchResultsVC.modalTransitionStyle = .crossDissolve
        searchResultsVC.delegate = self
        navigationController?.pushViewController(searchResultsVC, animated: true)
    }
    
    @objc private func calenderButtonPressed(){
        //        let vc = VC()
        //        navigationController?.pushViewController(vc, animated: true)
        
        let storyboard = UIStoryboard(name: "Post", bundle: nil)
        let postVC = storyboard.instantiateViewController(identifier: "PostViewController")
        navigationController?.pushViewController(postVC, animated: true)
    }
    
    //    private func addNavBarItems(){
    //            let barButtonItem = UIBarButtonItem(image: UIImage(systemName: "person.circle"), style: .plain, target: self, action: #selector(pushToFirstProfileViewController))
    //            navigationItem.rightBarButtonItem = barButtonItem
    //        }
    
    
    //    @objc private func pushToFirstProfileViewController(){
    //    //        let profileVC = ProfileViewController()
    //        let storyboard = UIStoryboard(name: "FirstProfileStoryboard", bundle: nil)
    //        let firstProfilelVC = storyboard.instantiateViewController(identifier: "FirstProfileViewController")
    //        navigationController?.pushViewController(firstProfilelVC, animated: true)
    //    }
    
    private func setupMap(){
        rootView.mapView.showsCompass = true
        rootView.mapView.showsUserLocation = true
        let usersLocation = locationSession.location
        let tempLocation = CLLocation(latitude: 40.8765478, longitude: -73.9089867)
        rootView.mapView.centerToLocation(tempLocation)
        rootView.searchByMapViewButton.isHidden = true
        topRightCoor = rootView.mapView.convert(CGPoint(x: rootView.mapView.bounds.width, y: 0), toCoordinateFrom: rootView.mapView)
        bottomLeftCoor = rootView.mapView.convert(CGPoint(x: 0, y: rootView.mapView.bounds.height), toCoordinateFrom: rootView.mapView)
    }
    
    private func setupCard(){
        visualEffectView = UIVisualEffectView()
        visualEffectView.frame = self.rootView.mapView.frame
        self.rootView.mapView.addSubview(visualEffectView)
        cardVC = CardViewController()
        cardVC.delegate = self
        self.addChild(cardVC)
        self.rootView.addSubview(cardVC.view)
        
        cardVC.view.frame = CGRect(x: 0, y: (self.view.frame.height - totalHeight) - cardHandleAreaHeight, width: self.view.bounds.width, height: cardHeight)
        cardVC.view.clipsToBounds = true
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleCardTap(recognizer:)))
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handleCardPan(recognizer:)))
        cardVC.handleArea.addGestureRecognizer(tapGestureRecognizer)
        cardVC.handleArea.addGestureRecognizer(panGestureRecognizer)
    }
    
    @objc func handleCardTap(recognizer: UITapGestureRecognizer){
        switch recognizer.state {
        case .ended:
            animateTransitionIfNeeded(state: nextState, duration: 0.9)
        default:
            break
        }
    }
    
    @objc func handleCardPan(recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            //startTransition
            startInteractiveTransition(state: nextState, duration: 0.9)
        case .changed:
            //updateTransition
            let translation = recognizer.translation(in: self.cardVC.handleArea)
            var fractionComplete = translation.y / cardHeight
            fractionComplete = cardVisible ? fractionComplete : -fractionComplete
            updateInteractiveTransition(fractionCompleted: fractionComplete)
        case .ended:
            //continueTransition
            continueInteractiveTransition()
        default:
            break
        }
    }
    
    func animateTransitionIfNeeded(state: CardState, duration: TimeInterval){
        if runningAnimations.isEmpty {
            let frameAnimator = UIViewPropertyAnimator(duration: duration, dampingRatio: 1) {
                switch state {
                case .expanded:
                    self.cardVC.view.frame.origin.y = (self.view.frame.height ) - self.cardHeight
                    if let layout = self.cardVC.cv.collectionViewLayout as? UICollectionViewFlowLayout {
                        layout.scrollDirection = .vertical
                    }
                case .collapsed:
                    self.cardVC.view.frame.origin.y = (self.view.frame.height - self.totalHeight) - self.cardHandleAreaHeight
                    if let layout = self.cardVC.cv.collectionViewLayout as? UICollectionViewFlowLayout {
                        layout.scrollDirection = .horizontal
                    }
                }
            }
            frameAnimator.addCompletion { (anim) in
                self.cardVisible = !self.cardVisible
                self.runningAnimations.removeAll()
            }
            frameAnimator.startAnimation()
            runningAnimations.append(frameAnimator)
            
            let cornerRadiusAnimator = UIViewPropertyAnimator(duration: duration, curve: .linear) {
                switch state {
                case .expanded:
                    self.cardVC.view.layer.cornerRadius
                        = 12
                case .collapsed:
                    self.cardVC.view.layer.cornerRadius = 0
                }
            }
            cornerRadiusAnimator.startAnimation()
            runningAnimations.append(cornerRadiusAnimator)
            
            let blurAnimator = UIViewPropertyAnimator(duration: duration, dampingRatio: 1) {
                switch state {
                case .expanded:
                    self.visualEffectView.effect = UIBlurEffect(style: .dark)
                case .collapsed:
                    self.visualEffectView.effect = nil
                }
            }
            blurAnimator.startAnimation()
            runningAnimations.append(blurAnimator)
        }
    }
    
    func startInteractiveTransition(state: CardState, duration: TimeInterval){
        if runningAnimations.isEmpty{
            //run animations
            animateTransitionIfNeeded(state: state, duration: duration)
        }
        
        for animator in runningAnimations {
            animator.pauseAnimation()
            animationProgressWhenInterrupted = animator.fractionComplete
        }
    }
    
    func updateInteractiveTransition(fractionCompleted: CGFloat) {
        for animator in runningAnimations {
            animator.fractionComplete = fractionCompleted + animationProgressWhenInterrupted
        }
    }
    
    func continueInteractiveTransition() {
        for animator in runningAnimations {
            animator.continueAnimation(withTimingParameters: nil, durationFactor: 0)
        }
    }
    
    @objc private func mapViewButtonPressed(){
        rootView.searchByMapViewButton.isHidden = true
        let latRange:ClosedRange<CLLocationDegrees>
        let longRange:ClosedRange<CLLocationDegrees>
        let topRightLat = topRightCoor.latitude
        let topRightLong = topRightCoor.longitude
        let bottomLeftLat = bottomLeftCoor.latitude
        let bottomLeftLong = bottomLeftCoor.longitude
        
        if topRightLat > bottomLeftLat {
            latRange = bottomLeftLat...topRightLat
        } else {
            latRange = topRightLat...bottomLeftLat
        }
        
        if topRightLong > bottomLeftLong{
            longRange = bottomLeftLong...topRightLong
        } else {
            longRange = topRightLong...bottomLeftLong
        }
        
        let latLongTuple = (lat: latRange, long: longRange)
        
        delegate?.readPostsFromMapView(given: latLongTuple)
    }
    
    @objc private func dateTimeButtonPressed(){
        let actionsheet = UIAlertController(title: "Nope, I mean...", message: nil, preferredStyle: .actionSheet)
        let dateButton = UIAlertAction(title: Date().toString(givenFormat: "E MM.dd"), style: .default) { (action) in
            //show calendar
            //selected dates stored on a property and used to filter with location
        }
        let timeButton = UIAlertAction(title: "\(Date().toString(givenFormat: "h:mm a")) - \(Date().addingTimeInterval(Double.hoursToSeconds(hours: 1)).toString(givenFormat: "h:mm a"))", style: .default) { (action) in
            //show timer
            //selected time frame stored on a property
        }
        let confirmButton = UIAlertAction(title: "Confirm", style: .default) { (action) in
            self.dismiss(animated: true) {
                //store and apply both date and time
            }
        }
        let cancelButton = UIAlertAction(title: "Cancel", style: .cancel) { (action) in
            self.dismiss(animated: true, completion: nil)
        }
        confirmButton.setValuesForKeys(
            [
                //"backgroundColor":UIColor.systemOrange,
                "titleTextColor":UIColor.systemOrange,
        ])
        
        let actions = [dateButton, timeButton, confirmButton, cancelButton]
        actions.forEach{actionsheet.addAction($0)}
        present(actionsheet, animated: true, completion: nil)
    }
    
    public func makeAnnotations(posts: [Post]) -> [MKPointAnnotation]? {
        var annotations = [MKPointAnnotation]()
        for post in posts {
            guard let lat = post.latitude, let long = post.longitude else {
                return nil
            }
            let coordinates = CLLocationCoordinate2D(latitude: lat, longitude: long)
            let annotation = MKPointAnnotation()
            annotation.title = post.postTitle
            annotation.coordinate = coordinates
            annotations.append(annotation)
        }
        //        let region = MKCoordinateRegion(center: coordinates, latitudinalMeters: 1500, longitudinalMeters: 1500)
        //        mapView.setRegion(region, animated: true)
        return annotations
    }
    
    private func validateMapRegion(_ region: MKCoordinateRegion?) -> MKCoordinateRegion?{
        guard let region = region else { return nil }
        if ( (region.center.latitude >= -90) && (region.center.latitude <= 90)     && (region.center.longitude >= -180)     && (region.center.longitude <= 180)) {
            return region
            } else {
            return nil
        }
    }
}

extension RootViewController: SearchPostDelegate{
    func readPostsFromSearchBar(given coordinate: CLLocationCoordinate2D, searchResult: String, region: MKCoordinateRegion?) {
        guard let region = validateMapRegion(region) else {
            return
        }
        mapView.setRegion(region, animated: true)
        
    }
    
    //    func readPostsFromSearchBar(given coordinate: CLLocationCoordinate2D, searchResult: String) {
    //        //map view to center location from addrr
    //
    //        self.rootView.mapView.centerToLocation(CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
    //    }
    
    func readPostsFromMapView(given coordinateRange: (lat: ClosedRange<CLLocationDegrees>, long: ClosedRange<CLLocationDegrees>)) {
        
    }
    
}

extension RootViewController: MKMapViewDelegate {
    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
        topRightCoor = rootView.mapView.convert(CGPoint(x: rootView.mapView.bounds.width, y: 0), toCoordinateFrom: rootView.mapView)
        bottomLeftCoor = rootView.mapView.convert(CGPoint(x: 0, y: rootView.mapView.bounds.height), toCoordinateFrom: rootView.mapView)
        rootView.searchByMapViewButton.isHidden = false
        //print("topRight",topRightCoor,"bottomLeft", bottomLeftCoor)
    }
}

extension RootViewController: CardViewControllerDelegate{
    func postsFound(posts: [Post], coordinateRange: (lat: ClosedRange<CLLocationDegrees>, long: ClosedRange<CLLocationDegrees>), region: MKCoordinateRegion) {
        guard let annotations = makeAnnotations(posts: posts) else {
            return
        }
        mapView.removeAnnotations(mapView.annotations)
        mapView.addAnnotations(annotations)
    }
    
    func postsFound(posts: [Post], geoHash: String, geoHashNeighbors: [String]?) {
        
    }
    
    func postsFound(posts: [Post], coordinateRange: (lat: ClosedRange<CLLocationDegrees>, long: ClosedRange<CLLocationDegrees>)) {
        guard let annotations = makeAnnotations(posts: posts) else {
            return
        }
        mapView.removeAnnotations(mapView.annotations)
        mapView.addAnnotations(annotations)
    }
}
