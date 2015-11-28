//
//  PhotoBrowserCollectionViewController.swift
//  Photomania
//
//  Created by Durul Dalkanat on 2015-08-20.
//  Copyright (c) 2015 Durul Dalkanat. All rights reserved.
//

import UIKit
import Alamofire

class PhotoBrowserCollectionViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout {
    
    var photos = NSMutableOrderedSet()
    let imageCache = NSCache()
    let refreshControl = UIRefreshControl()
    var populatingPhotos = false
    var currentPage = 1
    
    let PhotoBrowserCellIdentifier = "PhotoBrowserCell"
    let PhotoBrowserFooterViewIdentifier = "PhotoBrowserFooterView"
    
    // MARK: Life-cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        populatePhotos()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: CollectionView
    
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photos.count
        
    }
    
    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(PhotoBrowserCellIdentifier, forIndexPath: indexPath) as! PhotoBrowserCollectionViewCell
        
        let imageURL = (photos.objectAtIndex(indexPath.row) as! PhotoInfo).url
        
        // 1 The dequeued cell may already have an Alamofire request attached to it. You can simply cancel it because it’s no longer valid for this new cell.
        cell.request?.cancel()
        
         // 2 Use optional binding to check if you have a cached version of this photo. If so, use the cached version instead of downloading it again.
        if let image = self.imageCache.objectForKey(imageURL) as? UIImage{
            cell.imageView.image = image
        }else{
            // 3 If we don’t have a cached version of the photo, download it. However, the the dequeued cell may be already showing another image; in this case, set it to nil so that the cell is blank while the requested photo is downloaded.
            cell.imageView.image = nil
            
            // 4 Download the image from the server, but this time validate the content-type of the returned response. If it’s not an image, error will contain a value and therefore you won’t do anything with the potentially invalid image response. The key here is that you you store the Alamofire request object in the cell, for use when your asynchronous network call returns.
            
            cell.request = Alamofire.request(.GET, imageURL).validate(contentType: ["image/*"]).responseImage() {
                (req, _, result) in
                if result.error == nil && result.value != nil {
                    
                    // 5- If you did not receive an error and you downloaded a proper photo, cache it for later.
                    self.imageCache.setObject(result.value!, forKey: req!.URLString)
                    
                    // 6- Set the cell’s image accordingly.
                    cell.imageView.image = result.value
                } else {
                    /*
                    If the cell went off-screen before the image was downloaded, we cancel it and
                    an NSURLErrorDomain (-999: cancelled) is returned. This is a normal behavior.
                    */
                }
            }
        }
        
        return cell
    }
    
    override func collectionView(collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionReusableView {
        return collectionView.dequeueReusableSupplementaryViewOfKind(kind, withReuseIdentifier: PhotoBrowserFooterViewIdentifier, forIndexPath: indexPath) as UICollectionReusableView
    }
    
    override func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        performSegueWithIdentifier("ShowPhoto", sender: (self.photos.objectAtIndex(indexPath.item) as! PhotoInfo).id)
    }
    
    // MARK: Helper
    
    func setupView() {
        navigationController?.setNavigationBarHidden(false, animated: true)
        
        let layout = UICollectionViewFlowLayout()
        let itemWidth = (view.bounds.size.width - 2) / 3
        layout.itemSize = CGSize(width: itemWidth, height: itemWidth)
        layout.minimumInteritemSpacing = 1.0
        layout.minimumLineSpacing = 1.0
        layout.footerReferenceSize = CGSize(width: collectionView!.bounds.size.width, height: 100.0)
        
        collectionView!.collectionViewLayout = layout
        
        let titleLabel = UILabel(frame: CGRect(x: 0.0, y: 0.0, width: 60.0, height: 30.0))
        titleLabel.text = "Photomania"
        titleLabel.textColor = UIColor.whiteColor()
        titleLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline)
        navigationItem.titleView = titleLabel
        
        collectionView!.registerClass(PhotoBrowserCollectionViewCell.classForCoder(), forCellWithReuseIdentifier: PhotoBrowserCellIdentifier)
        collectionView!.registerClass(PhotoBrowserCollectionViewLoadingCell.classForCoder(), forSupplementaryViewOfKind: UICollectionElementKindSectionFooter, withReuseIdentifier: PhotoBrowserFooterViewIdentifier)
        
        refreshControl.tintColor = UIColor.whiteColor()
        refreshControl.addTarget(self, action: "handleRefresh", forControlEvents: .ValueChanged)
        collectionView!.addSubview(refreshControl)
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "ShowPhoto" {
            (segue.destinationViewController as! PhotoViewerViewController).photoID = sender!.integerValue
            (segue.destinationViewController as! PhotoViewerViewController).hidesBottomBarWhenPushed = true
        }
    }
    
    // 1- scrollViewDidScroll() loads more photos once you’ve scrolled through 80% of the view.
    override func scrollViewDidScroll(scrollView: UIScrollView) {
        if scrollView.contentOffset.y + view.frame.size.height > scrollView.contentSize.height * 0.8 {
            populatePhotos()
        }
    }
    
    func populatePhotos() {
        // 2 populatePhotos() loads photos in the currentPage and uses populatingPhotos as a flag to avoid loading the next page while you’re still loading the current page.
        
        if populatingPhotos {
            return
        }
        
        populatingPhotos = true
        
        // 3 You’re using your fancy router for the first time here. You simply pass in the page number and it constructs the URL string for that page. 500px.com returns at most 50 photos in each API call, so you’ll need to make another call for the next batch of photos.
        Alamofire.request(Five100px.Router.PopularPhotos(self.currentPage)).responseJSON() {
            (request, response, result) in
            
            if result.error == nil {
                
                // 4 Make careful note that the completion handler — the trailing closure of .responseJSON() — must run on the main thread. If you’re performing any long-running operations, such as making an API call, you must use GCD to dispatch your code on another queue. In this case, you’re using DISPATCH_QUEUE_PRIORITY_HIGH to run this activity.
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)) {
                    
                    // 5-  You’re interested in the photos key of the JSON response that includes an array of dictionaries. Each dictionary in the array contains information about one photo.
                    
                    //6- Here you use Swift’s filter function to filter out NSFW (Not Safe For Work) images.
                    
                    //7- The map function takes a closure and returns an array of PhotoInfo objects. This class is defined in Five100px.swift. If you look at the code of this class, you’ll see that it overrides both isEqual and hash. Both of these methods use an integer for the id property so ordering and uniquing PhotoInfo objects will still be a relatively fast operation.
                    let photoInfos = ((result.value as! NSDictionary).valueForKey("photos") as! [NSDictionary]).filter({ ($0["nsfw"] as! Bool) == false }).map { PhotoInfo(id: $0["id"] as! Int, url: $0["image_url"] as! String) }
                    
                    // 8 Next you store the current number of photos before you add the new batch; you’ll use this to update collectionView.
                    let lastItem = self.photos.count
                    
                    // 9 If someone uploaded new photos to 500px.com before you scrolled, the next batch of photos you get might contain a few photos that you’d already downloaded. That’s why you defined var photos = NSMutableOrderedSet() as a set; since all items in a set must be unique, this guarantees you won’t show a photo more than once.
                    self.photos.addObjectsFromArray(photoInfos)
                    
                    // 10 Here you create an array of NSIndexPath objects to insert into collectionView.
                    let indexPaths = (lastItem..<self.photos.count).map { NSIndexPath(forItem: $0, inSection: 0) }
                    
                    // 11 Inserts the items in the collection view – but does so on the main queue, because all UIKit operations must be done on the main queue.
                    dispatch_async(dispatch_get_main_queue()) {
                        self.collectionView!.insertItemsAtIndexPaths(indexPaths)
                    }
                    
                    self.currentPage++
                }
            }
            self.populatingPhotos = false
        }
    }
    
    func handleRefresh() {
        refreshControl.beginRefreshing()
        
        self.photos.removeAllObjects()
        self.currentPage = 1
        
        self.collectionView!.reloadData()
        
        refreshControl.endRefreshing()
        
        populatePhotos()
    }
}

class PhotoBrowserCollectionViewCell: UICollectionViewCell {
    let imageView = UIImageView()
    var request: Alamofire.Request?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        backgroundColor = UIColor(white: 0.1, alpha: 1.0)
        
        imageView.frame = bounds
        addSubview(imageView)
    }
}

class PhotoBrowserCollectionViewLoadingCell: UICollectionReusableView {
    let spinner = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.WhiteLarge)
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        spinner.startAnimating()
        spinner.center = self.center
        addSubview(spinner)
    }
}
