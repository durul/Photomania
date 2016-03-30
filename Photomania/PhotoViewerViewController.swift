//
//  PhotoViewerViewController.swift
//  Photomania
//
//  Created by Durul Dalkanat on 2015-08-24.
//  Copyright (c) 2015 Durul Dalkanat. All rights reserved.
//

import UIKit
import QuartzCore
import Alamofire

class PhotoViewerViewController: UIViewController, UIScrollViewDelegate, UIPopoverPresentationControllerDelegate, UIActionSheetDelegate {
    var photoID: Int = 0
    
    let scrollView = UIScrollView()
    let imageView = UIImageView()
    let spinner = UIActivityIndicatorView(activityIndicatorStyle: .WhiteLarge)
    
    var photoInfo: PhotoInfo?
    
    // MARK: Life-Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        loadPhoto()
    }
    
    // This time we making an Alamofire request inside another Alamofire request’s completion handler. The first request receives a JSON response and uses your new generic response serializer to create an instance of PhotoInfo out of that response.  (_, _, photoInfo: PhotoInfo?, error) in indicates the completion handler parameters: the first two underscores (“_” characters) mean the first two parameters are throwaways and there’s no need to explicitly name them request and response. The third parameter is explicitly declared as an instance of PhotoInfo, so the generic serializer automatically initializes and returns an object of this type, which contains the URL of the photo. The second Alamofire request uses the image serializer you created earlier to convert the NSData to a UIImage that you then display in an image view.
    func loadPhoto() {
        
        Alamofire.request(Five100px.Router.PhotoInfo(self.photoID, .Large)).validate().responseObject() {
            (_, _, result: Result<PhotoInfo>) in

            if result.error == nil {
                self.photoInfo = result.value
                
                dispatch_async(dispatch_get_main_queue()) {
                    self.addButtomBar()
                    self.title = self.photoInfo!.name
                }
                
                //The .validate() method call before requesting a response object is another easy-to-use Alamofire feature. Chaining it between your request and response validates that the response has a status code in the default acceptable range of 200 to 299. If validation fails, the response handler will have an associated error that you can deal with in your completion handler.
                //Even if there’s an error, your completion handler will still be called. The fourth parameter error is an instance of NSError,
                
                Alamofire.request(.GET, self.photoInfo!.url).validate().responseImage() {
                    (_, _, result) in
                    
                    if result.error == nil && result.value != nil {
                        self.imageView.image = result.value
                        self.imageView.frame = self.centerFrameFromImage(result.value)
                        self.spinner.stopAnimating()
                        self.centerScrollViewContents()
                    }
                }
            }
        }
    }
    
    func setupView() {
        navigationController?.setNavigationBarHidden(false, animated: true)
        
        spinner.center = CGPoint(x: view.center.x, y: view.center.y - view.bounds.origin.y / 2.0)
        spinner.hidesWhenStopped = true
        spinner.startAnimating()
        view.addSubview(spinner)
        
        scrollView.frame = view.bounds
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 3.0
        scrollView.zoomScale = 1.0
        view.addSubview(scrollView)
        
        imageView.contentMode = .ScaleAspectFill
        scrollView.addSubview(imageView)
        
        let doubleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(PhotoViewerViewController.handleDoubleTap(_:)))
        doubleTapRecognizer.numberOfTapsRequired = 2
        doubleTapRecognizer.numberOfTouchesRequired = 1
        scrollView.addGestureRecognizer(doubleTapRecognizer)
        
        let singleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(PhotoViewerViewController.handleSingleTap(_:)))
        singleTapRecognizer.numberOfTapsRequired = 1
        singleTapRecognizer.numberOfTouchesRequired = 1
        singleTapRecognizer.requireGestureRecognizerToFail(doubleTapRecognizer)
        scrollView.addGestureRecognizer(singleTapRecognizer)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        if photoInfo != nil {
            navigationController?.setToolbarHidden(false, animated: true)
        }
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setToolbarHidden(true, animated: true)
    }
    
    // MARK: Bottom Bar
    
    func addButtomBar() {
        var items = [UIBarButtonItem]()
        
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .FlexibleSpace, target: nil, action: nil)
        
        items.append(barButtonItemWithImageNamed("hamburger", title: nil, action: #selector(PhotoViewerViewController.showDetails)))
        
        if photoInfo?.commentsCount > 0 {
            items.append(barButtonItemWithImageNamed("bubble", title: "\(photoInfo?.commentsCount ?? 0)", action: #selector(PhotoViewerViewController.showComments)))
        }
        
        items.append(flexibleSpace)
        items.append(UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Action, target: self, action: #selector(PhotoViewerViewController.showActions)))
        items.append(flexibleSpace)
        
        items.append(barButtonItemWithImageNamed("like", title: "\(photoInfo?.votesCount ?? 0)"))
        items.append(barButtonItemWithImageNamed("heart", title: "\(photoInfo?.favoritesCount ?? 0)"))
        
        self.setToolbarItems(items, animated: true)
        navigationController?.setToolbarHidden(false, animated: true)
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: userInfoViewForPhotoInfo(photoInfo!))
    }
    
    func userInfoViewForPhotoInfo(photoInfo: PhotoInfo) -> UIView {
        let userProfileImageView = UIImageView(frame: CGRect(x: 0, y: 10.0, width: 30.0, height: 30.0))
        userProfileImageView.layer.cornerRadius = 3.0
        userProfileImageView.layer.masksToBounds = true
        
        return userProfileImageView
    }
    
    func showDetails() {
        let photoDetailsViewController = storyboard?.instantiateViewControllerWithIdentifier("PhotoDetails") as? PhotoDetailsViewController
        photoDetailsViewController?.modalPresentationStyle = .OverCurrentContext
        photoDetailsViewController?.modalTransitionStyle = .CoverVertical
        photoDetailsViewController?.photoInfo = photoInfo
        
        presentViewController(photoDetailsViewController!, animated: true, completion: nil)
    }
    
    func showComments() {
        let photoCommentsViewController = storyboard?.instantiateViewControllerWithIdentifier("PhotoComments") as? PhotoCommentsViewController
        photoCommentsViewController?.modalPresentationStyle = .Popover
        photoCommentsViewController?.modalTransitionStyle = .CoverVertical
        photoCommentsViewController?.photoID = photoID
        photoCommentsViewController?.popoverPresentationController?.delegate = self
        presentViewController(photoCommentsViewController!, animated: true, completion: nil)
    }
    
    func adaptivePresentationStyleForPresentationController(controller: UIPresentationController) -> UIModalPresentationStyle {
        return UIModalPresentationStyle.OverCurrentContext
    }
    
    func presentationController(controller: UIPresentationController, viewControllerForAdaptivePresentationStyle style: UIModalPresentationStyle) -> UIViewController? {
        let navController = UINavigationController(rootViewController: controller.presentedViewController)
        
        return navController
    }
    
    func barButtonItemWithImageNamed(imageName: String?, title: String?, action: Selector? = nil) -> UIBarButtonItem {
        
        let button = UIButton(type:.Custom)
        
        if imageName != nil {
            button.setImage(UIImage(named: imageName!)!.imageWithRenderingMode(.AlwaysTemplate), forState: .Normal)
        }
        
        if title != nil {
            button.setTitle(title, forState: .Normal)
            button.titleEdgeInsets = UIEdgeInsets(top: 0.0, left: 10.0, bottom: 0.0, right: 0.0)
            
            let font = UIFont.preferredFontForTextStyle(UIFontTextStyleFootnote)
            button.titleLabel?.font = font
        }
        
        let size = button.sizeThatFits(CGSize(width: 90.0, height: 30.0))
        button.frame.size = CGSize(width: min(size.width + 10.0, 60), height: size.height)
        
        if action != nil {
            button.addTarget(self, action: action!, forControlEvents: .TouchUpInside)
        }
        
        let barButton = UIBarButtonItem(customView: button)
        
        return barButton
    }
    
    // MARK: Download Photo
    
    func showActions() {
        let actionSheet = UIActionSheet(title: nil, delegate: self, cancelButtonTitle: "Cancel", destructiveButtonTitle: nil, otherButtonTitles: "Download Photo")
        actionSheet.showFromToolbar((navigationController?.toolbar)!)
    }
    
    func actionSheet(actionSheet: UIActionSheet, clickedButtonAtIndex buttonIndex: Int) {
        if buttonIndex == 1 {
            downloadPhoto()
        }
    }
    
    func downloadPhoto() {
        
        // 1- We first request a new PhotoInfo, only this time asking for an XLarge size image.
        Alamofire.request(Five100px.Router.PhotoInfo(photoInfo!.id, .XLarge)).validate().responseJSON() {
            (request, response, result) in
            
            if result.error == nil {
                let jsonDictionary = (result.value as! NSDictionary)
                let imageURL = jsonDictionary.valueForKeyPath("photo.image_url") as! String
                
                // 2- Get the default location on disk to which to save your files — this will be a subdirectory in the Documents directory of your app. The name of the file on disk will be the same as the name that the server suggests. destination is a closure in disguise — more on that in just a moment.
                let destination: (NSURL, NSHTTPURLResponse) -> (NSURL) = {
                    (temporaryURL, response) in
                    
                    if let directoryURL: NSURL = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)[0] {
                        return directoryURL.URLByAppendingPathComponent("\(self.photoInfo!.id).\(response.suggestedFilename)")
                    }
                    
                    return temporaryURL
                }
                
                // 3
                // Alamofire.download(.GET, imageURL, destination: destination)
                
                // 4- We use a standard UIProgressView to show the progress of downloading a photo. Set it up and add it to the view hierarchy.
                let progressIndicatorView = UIProgressView(frame: CGRect(x: 0.0, y: 80.0, width: self.view.bounds.width, height: 10.0))
                progressIndicatorView.tintColor = UIColor.blueColor()
                self.view.addSubview(progressIndicatorView)
                
                // 5- With Alamofire you can chain .progress(), which takes a closure called periodically with three parameters: bytesRead, totalBytesRead, totalBytesExpectedToRead.
                Alamofire.download(.GET, imageURL, destination: destination).progress {
                    (_, totalBytesRead, totalBytesExpectedToRead) in
                    
                    dispatch_async(dispatch_get_main_queue()) {
                        // 6 Simply divide totalBytesRead by totalBytesExpectedToRead and you’ll get a number between 0 and 1 that represents the progress of the download task. This closure may execute multiple times if the if the download time isn’t near-instantaneous; each execution gives you a chance to update a progress bar on the screen.
                        progressIndicatorView.setProgress(Float(totalBytesRead) / Float(totalBytesExpectedToRead), animated: true)
                        
                        // 7 Once the download is finished, simply remove the progress bar from the view hierarchy.
                        if totalBytesRead == totalBytesExpectedToRead {
                            progressIndicatorView.removeFromSuperview()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: Gesture Recognizers
    
    func handleDoubleTap(recognizer: UITapGestureRecognizer!) {
        let pointInView = recognizer.locationInView(self.imageView)
        self.zoomInZoomOut(pointInView)
    }
    
    func handleSingleTap(recognizer: UITapGestureRecognizer!) {
        let hidden = navigationController?.navigationBar.hidden ?? false
        navigationController?.setNavigationBarHidden(!hidden, animated: true)
        navigationController?.setToolbarHidden(!hidden, animated: true)
        UIApplication.sharedApplication().setStatusBarHidden(!hidden, withAnimation: .Slide)
    }
    
    // MARK: ScrollView
    
    func centerFrameFromImage(image: UIImage?) -> CGRect {
        if image == nil {
            return CGRectZero
        }
        
        let scaleFactor = scrollView.frame.size.width / image!.size.width
        let newHeight = image!.size.height * scaleFactor
        
        var newImageSize = CGSize(width: scrollView.frame.size.width, height: newHeight)
        
        newImageSize.height = min(scrollView.frame.size.height, newImageSize.height)
        
        let centerFrame = CGRect(x: 0.0, y: scrollView.frame.size.height/2 - newImageSize.height/2, width: newImageSize.width, height: newImageSize.height)
        
        return centerFrame
    }
    
    func scrollViewDidZoom(scrollView: UIScrollView) {
        self.centerScrollViewContents()
    }
    
    func centerScrollViewContents() {
        let boundsSize = scrollView.frame
        var contentsFrame = self.imageView.frame
        
        if contentsFrame.size.width < boundsSize.width {
            contentsFrame.origin.x = (boundsSize.width - contentsFrame.size.width) / 2.0
        } else {
            contentsFrame.origin.x = 0.0
        }
        
        if contentsFrame.size.height < boundsSize.height {
            contentsFrame.origin.y = (boundsSize.height - scrollView.scrollIndicatorInsets.top - scrollView.scrollIndicatorInsets.bottom - contentsFrame.size.height) / 2.0
        } else {
            contentsFrame.origin.y = 0.0
        }
        
        self.imageView.frame = contentsFrame
    }
    
    func viewForZoomingInScrollView(scrollView: UIScrollView) -> UIView? {
        return self.imageView
    }
    
    func zoomInZoomOut(point: CGPoint!) {
        let newZoomScale = self.scrollView.zoomScale > (self.scrollView.maximumZoomScale/2) ? self.scrollView.minimumZoomScale : self.scrollView.maximumZoomScale
        
        let scrollViewSize = self.scrollView.bounds.size
        
        let width = scrollViewSize.width / newZoomScale
        let height = scrollViewSize.height / newZoomScale
        let x = point.x - (width / 2.0)
        let y = point.y - (height / 2.0)
        
        let rectToZoom = CGRect(x: x, y: y, width: width, height: height)
        
        self.scrollView.zoomToRect(rectToZoom, animated: true)
    }
}
