//
//  ViewController.swift
//  FlickFinder
//
//  Created by Azuka Omesiete on 07/5/16.
//  Copyright © 2016 Azuka Omesiete. All rights reserved.
//

import UIKit

// MARK: - ViewController: UIViewController

class ViewController: UIViewController {
    
    // MARK: Properties
    
    var keyboardOnScreen = false
    
    // MARK: Outlets
    
    @IBOutlet weak var photoImageView: UIImageView!
    @IBOutlet weak var photoTitleLabel: UILabel!
    @IBOutlet weak var phraseTextField: UITextField!
    @IBOutlet weak var phraseSearchButton: UIButton!
    @IBOutlet weak var latitudeTextField: UITextField!
    @IBOutlet weak var longitudeTextField: UITextField!
    @IBOutlet weak var latLonSearchButton: UIButton!
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        phraseTextField.delegate = self
        latitudeTextField.delegate = self
        longitudeTextField.delegate = self
        // FIX: As of Swift 2.2, using strings for selectors has been deprecated. Instead, #selector(methodName) should be used.
        subscribeToNotification(UIKeyboardWillShowNotification, selector: #selector(keyboardWillShow))
        subscribeToNotification(UIKeyboardWillHideNotification, selector: #selector(keyboardWillHide))
        subscribeToNotification(UIKeyboardDidShowNotification, selector: #selector(keyboardDidShow))
        subscribeToNotification(UIKeyboardDidHideNotification, selector: #selector(keyboardDidHide))
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        unsubscribeFromAllNotifications()
    }
    
    // MARK: Search Actions
    
    @IBAction func searchByPhrase(sender: AnyObject) {
        
        userDidTapView(self)
        setUIEnabled(false)
        
        if !phraseTextField.text!.isEmpty {
            photoTitleLabel.text = "Searching..."
            // TODO: Set necessary parameters!
            let methodParameters: [String: String!] = [Constants.FlickrParameterKeys.SafeSearch: Constants.FlickrParameterValues.UseSafeSearch,
                                                       Constants.FlickrParameterKeys.Text: self.phraseTextField.text, Constants.FlickrParameterKeys.Extras: Constants.FlickrParameterValues.MediumURL, Constants.FlickrParameterKeys.APIKey: Constants.FlickrParameterValues.APIKey,   Constants.FlickrParameterKeys.Method: Constants.FlickrParameterValues.SearchMethod, Constants.FlickrParameterKeys.Format: Constants.FlickrParameterValues.ResponseFormat,
                                                       Constants.FlickrParameterKeys.NoJSONCallback: Constants.FlickrParameterValues.DisableJSONCallback]
            
            
            displayImageFromFlickrBySearch(methodParameters)
        } else {
            setUIEnabled(true)
            photoTitleLabel.text = "Phrase Empty."
        }
    }
    
    
    
    @IBAction func searchByLatLon(sender: AnyObject) {
        
        userDidTapView(self)
        setUIEnabled(false)
        
        if isTextFieldValid(latitudeTextField, forRange: Constants.Flickr.SearchLatRange) && isTextFieldValid(longitudeTextField, forRange: Constants.Flickr.SearchLonRange) {
            photoTitleLabel.text = "Searching..."
            // TODO: Set necessary parameters!
            let methodParameters: [String: String!] = [Constants.FlickrParameterKeys.SafeSearch: Constants.FlickrParameterValues.UseSafeSearch,
                                                       Constants.FlickrParameterKeys.Extras: Constants.FlickrParameterValues.MediumURL,
                                                       Constants.FlickrParameterKeys.BoundingBox:bboxString(),
                                                       Constants.FlickrParameterKeys.APIKey: Constants.FlickrParameterValues.APIKey,   Constants.FlickrParameterKeys.Method: Constants.FlickrParameterValues.SearchMethod, Constants.FlickrParameterKeys.Format: Constants.FlickrParameterValues.ResponseFormat,
                                                       Constants.FlickrParameterKeys.NoJSONCallback: Constants.FlickrParameterValues.DisableJSONCallback]
            
            
            displayImageFromFlickrBySearch(methodParameters)
        }
        else {
            setUIEnabled(true)
            photoTitleLabel.text = "Lat should be [-90, 90].\nLon should be [-180, 180]."
        }
    }
    
    private func bboxString() -> String {
        var latBound: Double = 0.0
        var longBound: Double = 0.0
        let latBoundA = (latitudeTextField.text! as NSString).doubleValue
        let longBoundA = (longitudeTextField.text! as NSString).doubleValue
        
        
        latBound = latBoundA + Constants.Flickr.SearchBBoxHalfHeight
        longBound = longBoundA + Constants.Flickr.SearchBBoxHalfWidth
        
        //       if  (latBound,latBoundA) > Constants.Flickr.SearchLatRange {
        //          latLonSearchButton.enabled = false
        //       }
        return("\(latBoundA),\(longBoundA),\(latBound),\(longBound)")
        
    }
    
    // MARK: Flickr API
    
    private func displayImageFromFlickrBySearch(methodParameters: [String:AnyObject]) {
        
        let session = NSURLSession.sharedSession()
        let urlString = flickrURLFromParameters(methodParameters)
   
        let request = NSURLRequest(URL: flickrURLFromParameters(methodParameters))
      
        let task = session.dataTaskWithRequest(request) { (data, response, error) in
            if error == nil {
                print(data)
            } else {
                print("You have an error here")
            }
            
            
            func displayError(error: String) {
                print(error)
                print("URL at time of error")
                performUIUpdatesOnMain {
                    self.setUIEnabled(true)
                }
            }
            
            /* GUARD: Was there an error? */
            guard (error == nil) else {
                displayError("There was an error with your request")
                return
            }
            /* GUARD: Did we get a successful 2XX response? */
            guard let statusCode = (response as? NSHTTPURLResponse)?.statusCode where statusCode >= 200 && statusCode <= 299 else {
                displayError("Your request returned a status code other than 2xx!")
                return
            }
            
            
            // parse the data
            let parsedResult: AnyObject!
            do {
                parsedResult = try NSJSONSerialization.JSONObjectWithData(data!, options: .AllowFragments)
            } catch {
                displayError("Could not parse the data as JSON: '\(data)'")
                return
            }
            
            /* GUARD: Are the "photos" and "photo" keys in our result? */
            guard let photosDictionary = parsedResult[Constants.FlickrResponseKeys.Photos] as? [String:AnyObject],
                photoArray = photosDictionary[Constants.FlickrResponseKeys.Photo] as? [[String:AnyObject]] else {
                    displayError("Cannot find keys '\(Constants.FlickrResponseKeys.Photos)' and '\(Constants.FlickrResponseKeys.Photo)' in \(parsedResult)")
                    return
            }
            
            // select a random photo
            let randomPhotoIndex = Int(arc4random_uniform(UInt32(photoArray.count)))
            let photoDictionary = photoArray[randomPhotoIndex] as [String:AnyObject]
            let photoTitle = photoDictionary[Constants.FlickrResponseKeys.Title] as? String
            
            guard let imageUrlString = photoDictionary[Constants.FlickrResponseKeys.MediumURL] as? String else {
                displayError("Cannot find key '\(Constants.FlickrResponseKeys.MediumURL)' in \(photoDictionary)")
                return
            }
            
            let imageURL = NSURL(string: imageUrlString)
            if let imageData = NSData(contentsOfURL: imageURL!) {
                performUIUpdatesOnMain {
                    self.setUIEnabled(true)
                    self.photoImageView.image = UIImage(data: imageData)
                    self.photoTitleLabel.text = photoTitle ?? "(Untitled)"
                }
            } else {
                displayError("Image does not exist at ")
            }
        }
        task.resume()
        print(flickrURLFromParameters(methodParameters))
    }
    
    // MARK: Helper for Creating a URL from Parameters
    
    private func flickrURLFromParameters(parameters: [String:AnyObject]) -> NSURL {
        
        let components = NSURLComponents()
        components.scheme = Constants.Flickr.APIScheme
        components.host = Constants.Flickr.APIHost
        components.path = Constants.Flickr.APIPath
        components.queryItems = [NSURLQueryItem]()
        components.queryItems = [NSURLQueryItem]()
        
        for (key, value) in parameters {
            let queryItem = NSURLQueryItem(name: key, value: "\(value)")
            components.queryItems!.append(queryItem)
        }
        return components.URL!
    }
}

// MARK: - ViewController: UITextFieldDelegate

extension ViewController: UITextFieldDelegate {
    
    // MARK: UITextFieldDelegate
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    // MARK: Show/Hide Keyboard
    
    func keyboardWillShow(notification: NSNotification) {
        if !keyboardOnScreen {
            view.frame.origin.y -= keyboardHeight(notification)
        }
    }
    
    func keyboardWillHide(notification: NSNotification) {
        if keyboardOnScreen {
            view.frame.origin.y += keyboardHeight(notification)
        }
    }
    
    func keyboardDidShow(notification: NSNotification) {
        keyboardOnScreen = true
    }
    
    func keyboardDidHide(notification: NSNotification) {
        keyboardOnScreen = false
    }
    
    private func keyboardHeight(notification: NSNotification) -> CGFloat {
        let userInfo = notification.userInfo
        let keyboardSize = userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue
        return keyboardSize.CGRectValue().height
    }
    
    private func resignIfFirstResponder(textField: UITextField) {
        if textField.isFirstResponder() {
            textField.resignFirstResponder()
        }
    }
    
    @IBAction func userDidTapView(sender: AnyObject) {
        resignIfFirstResponder(phraseTextField)
        resignIfFirstResponder(latitudeTextField)
        resignIfFirstResponder(longitudeTextField)
    }
    
    // MARK: TextField Validation
    
    private func isTextFieldValid(textField: UITextField, forRange: (Double, Double)) -> Bool {
        if let value = Double(textField.text!) where !textField.text!.isEmpty {
            return isValueInRange(value, min: forRange.0, max: forRange.1)
        } else {
            return false
        }
    }
    
    private func isValueInRange(value: Double, min: Double, max: Double) -> Bool {
        return !(value < min || value > max)
    }
}

// MARK: - ViewController (Configure UI)

extension ViewController {
    
    private func setUIEnabled(enabled: Bool) {
        photoTitleLabel.enabled = enabled
        phraseTextField.enabled = enabled
        latitudeTextField.enabled = enabled
        longitudeTextField.enabled = enabled
        phraseSearchButton.enabled = enabled
        latLonSearchButton.enabled = enabled
        
        // adjust search button alphas
        if enabled {
            phraseSearchButton.alpha = 1.0
            latLonSearchButton.alpha = 1.0
        } else {
            phraseSearchButton.alpha = 0.5
            latLonSearchButton.alpha = 0.5
        }
    }
}

// MARK: - ViewController (Notifications)

extension ViewController {
    
    private func subscribeToNotification(notification: String, selector: Selector) {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: selector, name: notification, object: nil)
    }
    
    private func unsubscribeFromAllNotifications() {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
}

extension String {
    var doubleValue: Double {
        return (self as NSString).doubleValue
    }
}