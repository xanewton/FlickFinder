//
//  ViewController.swift
//  FlickFinder
//
//  Created by xengar on 2017-11-24.
//  Copyright © 2017 xengar. All rights reserved.
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
        subscribeToNotification(.UIKeyboardWillShow, selector: #selector(keyboardWillShow))
        subscribeToNotification(.UIKeyboardWillHide, selector: #selector(keyboardWillHide))
        subscribeToNotification(.UIKeyboardDidShow, selector: #selector(keyboardDidShow))
        subscribeToNotification(.UIKeyboardDidHide, selector: #selector(keyboardDidHide))
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        unsubscribeFromAllNotifications()
    }
    
    // MARK: Search Actions
    
    @IBAction func searchByPhrase(_ sender: AnyObject) {
        
        userDidTapView(self)
        setUIEnabled(false)
        
        if !phraseTextField.text!.isEmpty {
            photoTitleLabel.text = "Searching..."
            
            // Set necessary parameters!
            var methodParameters: [String: AnyObject] = [:]
            methodParameters[Constants.FlickrParameterKeys.SafeSearch] = Constants.FlickrParameterValues.UseSafeSearch as AnyObject
            methodParameters[Constants.FlickrParameterKeys.Text] = phraseTextField.text as AnyObject
            methodParameters[Constants.FlickrParameterKeys.Extras] = Constants.FlickrParameterValues.MediumURL as AnyObject
            methodParameters[Constants.FlickrParameterKeys.APIKey] = Constants.FlickrParameterValues.APIKey as AnyObject
            methodParameters[Constants.FlickrParameterKeys.Method] = Constants.FlickrParameterValues.PhotoSearchMethod as AnyObject
            methodParameters[Constants.FlickrParameterKeys.Format] = Constants.FlickrParameterValues.ResponseFormat as AnyObject
            methodParameters[Constants.FlickrParameterKeys.NoJSONCallback] = Constants.FlickrParameterValues.DisableJSONCallback as AnyObject
            
            displayImageFromFlickrBySearch(methodParameters)
        } else {
            setUIEnabled(true)
            photoTitleLabel.text = "Phrase Empty."
        }
    }
    
    @IBAction func searchByLatLon(_ sender: AnyObject) {
        
        userDidTapView(self)
        setUIEnabled(false)
        
        if isTextFieldValid(latitudeTextField, forRange: Constants.Flickr.SearchLatRange) && isTextFieldValid(longitudeTextField, forRange: Constants.Flickr.SearchLonRange) {
            photoTitleLabel.text = "Searching..."
            
            // Set necessary parameters!
            var methodParameters: [String: AnyObject] = [:]
            methodParameters[Constants.FlickrParameterKeys.SafeSearch] = Constants.FlickrParameterValues.UseSafeSearch as AnyObject
            methodParameters[Constants.FlickrParameterKeys.Extras] = Constants.FlickrParameterValues.MediumURL as AnyObject
            methodParameters[Constants.FlickrParameterKeys.BoundingBox] = bboxString() as AnyObject
            methodParameters[Constants.FlickrParameterKeys.APIKey] = Constants.FlickrParameterValues.APIKey as AnyObject
            methodParameters[Constants.FlickrParameterKeys.Method] = Constants.FlickrParameterValues.PhotoSearchMethod as AnyObject
            methodParameters[Constants.FlickrParameterKeys.Format] = Constants.FlickrParameterValues.ResponseFormat as AnyObject
            methodParameters[Constants.FlickrParameterKeys.NoJSONCallback] = Constants.FlickrParameterValues.DisableJSONCallback as AnyObject
            
            displayImageFromFlickrBySearch(methodParameters)
        }
        else {
            setUIEnabled(true)
            photoTitleLabel.text = "Lat should be [-90, 90].\nLon should be [-180, 180]."
        }
    }
    
    // Create the latitude and longitude area to search.
    // See https://www.flickr.com/services/api/flickr.photos.search.html
    private func bboxString() -> String {
        // A comma-delimited list of 4 values defining the Bounding Box of the area that will be searched.
        // The 4 values represent the bottom-left corner of the box and the top-right corner, minimum_longitude, minimum_latitude, maximum_longitude, maximum_latitude.
        
        if let latitude = Double(latitudeTextField.text!), let longitude = Double(longitudeTextField.text!) {
            // Longitude has a range of -180 to 180 , latitude of -90 to 90. Defaults to -180, -90, 180, 90 if not specified.
            let minimumLongitude : Double = max(longitude - Constants.Flickr.SearchBBoxHalfWidth, Constants.Flickr.SearchLonRange.0)
            let minimumLatitude : Double = max(latitude - Constants.Flickr.SearchBBoxHalfHeight, Constants.Flickr.SearchLatRange.0)
            let maximumLongitude : Double = min(longitude + Constants.Flickr.SearchBBoxHalfWidth, Constants.Flickr.SearchLonRange.1)
            let maximumLatitude : Double = min(latitude + Constants.Flickr.SearchBBoxHalfHeight, Constants.Flickr.SearchLatRange.1)
            
            return "\(minimumLongitude),\(minimumLatitude),\(maximumLongitude),\(maximumLatitude)"
        } else {
            return "0,0,0,0"
        }
    }
    
    
    // MARK: Flickr API
    
    private func displayImageFromFlickrBySearch(_ methodParameters: [String: AnyObject]) {
        
        print(flickrURLFromParameters(methodParameters))
        // Make request to Flickr!
        
        // create session and request
        let session = URLSession.shared
        let request = URLRequest(url: flickrURLFromParameters(methodParameters))
        
        // create network request
        let task = session.dataTask(with: request) { (data, response, error) in
            
            func displayError(error: String) {
                print(error)
                performUIUpdatesOnMain {
                    self.setUIEnabled(true)
                    self.photoTitleLabel.text = "No photo returned. Try again."
                    self.photoImageView.image = nil
                }
            }
            
            /* GUARD: Was there an error? */
            guard (error == nil) else {
                displayError(error: "There was an error with your request: \(String(describing: error))")
                return
            }
            
            /* GUARD: Did we get a successful 2XX response? */
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else {
                displayError(error: "Your request returned a status code other than 2xx!")
                return
            }
            
            /* GUARD: Was there any data returned? */
            guard let data = data else {
                displayError(error: "No data was returned by the request!")
                return
            }
            
            // parse the data
            let parsedResult: [String:AnyObject]!
            do {
                parsedResult = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String:AnyObject]
            } catch {
                displayError(error: "Could not parse the data as JSON: '\(data)'")
                return
            }
            
            /* GUARD: Did Flickr return an error (stat != ok)? */
            guard let stat = parsedResult[Constants.FlickrResponseKeys.Status] as? String, stat == Constants.FlickrResponseValues.OKStatus else {
                displayError(error: "Flickr API returned an error. See error code and message in \(parsedResult)")
                return
            }
            
            /* GUARD: Are the "photos" and "photo" keys in our result? */
            guard let photosDictionary = parsedResult[Constants.FlickrResponseKeys.Photos] as? [String:AnyObject], let photoArray = photosDictionary[Constants.FlickrResponseKeys.Photo] as? [[String:AnyObject]] else {
                displayError(error: "Cannot find keys '\(Constants.FlickrResponseKeys.Photos)' and '\(Constants.FlickrResponseKeys.Photo)' in \(parsedResult)")
                return
            }
            
            
            //print(parsedResult)
            /* GUARD: Are the "pages" key in our result? */
            guard let resultPages = photosDictionary[Constants.FlickrResponseKeys.Pages] as? Int else {
                displayError(error: "Cannot find pages '\(Constants.FlickrResponseKeys.Pages)' in \(photosDictionary)")
                return
            }
            
            let randomPage = Int(arc4random_uniform(UInt32(min(resultPages, 40))))
            print("resultPages: \(resultPages)  randomPage: \(randomPage)")
            // Make the same request with the random page
            self.displayImageFromFlickrBySearch(methodParameters, withPageNumber: randomPage)
            
        }
        
        task.resume()
    }
    
    // Make request to Flickr!
    private func displayImageFromFlickrBySearch(_ methodParameters: [String: AnyObject], withPageNumber: Int) {
        // add the page to the method's parameters
        var methodParametersWithPageNumber = methodParameters
        methodParametersWithPageNumber[Constants.FlickrParameterKeys.Page] = withPageNumber as AnyObject?
        
        // [remaining code in the function]...
        // create session and request
        let session = URLSession.shared
        let request = URLRequest(url: flickrURLFromParameters(methodParametersWithPageNumber))
        // create network request
        let task = session.dataTask(with: request) { (data, response, error) in
            
            func displayError(error: String) {
                print(error)
                performUIUpdatesOnMain {
                    self.setUIEnabled(true)
                    self.photoTitleLabel.text = "No photo returned. Try again."
                    self.photoImageView.image = nil
                }
            }
            
            /* GUARD: Was there an error? */
            guard (error == nil) else {
                displayError(error: "There was an error with your request: \(String(describing: error))")
                return
            }
            
            /* GUARD: Did we get a successful 2XX response? */
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else {
                displayError(error: "Your request returned a status code other than 2xx!")
                return
            }
            
            /* GUARD: Was there any data returned? */
            guard let data = data else {
                displayError(error: "No data was returned by the request!")
                return
            }
            
            // parse the data
            let parsedResult: [String:AnyObject]!
            do {
                parsedResult = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String:AnyObject]
            } catch {
                displayError(error: "Could not parse the data as JSON: '\(data)'")
                return
            }
            
            /* GUARD: Did Flickr return an error (stat != ok)? */
            guard let stat = parsedResult[Constants.FlickrResponseKeys.Status] as? String, stat == Constants.FlickrResponseValues.OKStatus else {
                displayError(error: "Flickr API returned an error. See error code and message in \(parsedResult)")
                return
            }
            
            /* GUARD: Are the "photos" and "photo" keys in our result? */
            guard let photosDictionary = parsedResult[Constants.FlickrResponseKeys.Photos] as? [String:AnyObject], let photoArray = photosDictionary[Constants.FlickrResponseKeys.Photo] as? [[String:AnyObject]] else {
                displayError(error: "Cannot find keys '\(Constants.FlickrResponseKeys.Photos)' and '\(Constants.FlickrResponseKeys.Photo)' in \(parsedResult)")
                return
            }
            
            // select a random photo
            let randomPhotoIndex = Int(arc4random_uniform(UInt32(photoArray.count)))
            let photoDictionary = photoArray[randomPhotoIndex] as [String:AnyObject]
            let photoTitle = photoDictionary[Constants.FlickrResponseKeys.Title] as? String
            
            /* GUARD: Does our photo have a key for 'url_m'? */
            guard let imageUrlString = photoDictionary[Constants.FlickrResponseKeys.MediumURL] as? String else {
                displayError(error: "Cannot find key '\(Constants.FlickrResponseKeys.MediumURL)' in \(photoDictionary)")
                return
            }
            
            // if an image exists at the url, set the image and title
            let imageURL = URL(string: imageUrlString)
            if let imageData = try? Data(contentsOf: imageURL!) {
                performUIUpdatesOnMain {
                    self.setUIEnabled(true)
                    self.photoImageView.image = UIImage(data: imageData)
                    self.photoTitleLabel.text = photoTitle ?? "(Untitled)"
                }
            } else {
                displayError(error: "Image does not exist at \(String(describing: imageURL))")
            }
            
        }
        
        task.resume()
    }
    
    
    // MARK: Helper for Creating a URL from Parameters
    private func flickrURLFromParameters(_ parameters: [String: AnyObject]) -> URL {
        
        var components = URLComponents()
        components.scheme = Constants.Flickr.APIScheme
        components.host = Constants.Flickr.APIHost
        components.path = Constants.Flickr.APIPath
        components.queryItems = [URLQueryItem]()
        
        for (key, value) in parameters {
            let queryItem = URLQueryItem(name: key, value: "\(value)")
            components.queryItems!.append(queryItem)
        }
        
        return components.url!
    }
}

// MARK: - ViewController: UITextFieldDelegate

extension ViewController: UITextFieldDelegate {
    
    // MARK: UITextFieldDelegate
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    // MARK: Show/Hide Keyboard
    
    @objc func keyboardWillShow(_ notification: Notification) {
        if !keyboardOnScreen {
            view.frame.origin.y -= keyboardHeight(notification)
        }
    }
    
    @objc func keyboardWillHide(_ notification: Notification) {
        if keyboardOnScreen {
            view.frame.origin.y += keyboardHeight(notification)
        }
    }
    
    @objc func keyboardDidShow(_ notification: Notification) {
        keyboardOnScreen = true
    }
    
    @objc func keyboardDidHide(_ notification: Notification) {
        keyboardOnScreen = false
    }
    
    func keyboardHeight(_ notification: Notification) -> CGFloat {
        let userInfo = (notification as NSNotification).userInfo
        let keyboardSize = userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue
        return keyboardSize.cgRectValue.height
    }
    
    func resignIfFirstResponder(_ textField: UITextField) {
        if textField.isFirstResponder {
            textField.resignFirstResponder()
        }
    }
    
    @IBAction func userDidTapView(_ sender: AnyObject) {
        resignIfFirstResponder(phraseTextField)
        resignIfFirstResponder(latitudeTextField)
        resignIfFirstResponder(longitudeTextField)
    }
    
    // MARK: TextField Validation
    
    func isTextFieldValid(_ textField: UITextField, forRange: (Double, Double)) -> Bool {
        if let value = Double(textField.text!), !textField.text!.isEmpty {
            return isValueInRange(value, min: forRange.0, max: forRange.1)
        } else {
            return false
        }
    }
    
    func isValueInRange(_ value: Double, min: Double, max: Double) -> Bool {
        return !(value < min || value > max)
    }
}

// MARK: - ViewController (Configure UI)

private extension ViewController {
    
    func setUIEnabled(_ enabled: Bool) {
        photoTitleLabel.isEnabled = enabled
        phraseTextField.isEnabled = enabled
        latitudeTextField.isEnabled = enabled
        longitudeTextField.isEnabled = enabled
        phraseSearchButton.isEnabled = enabled
        latLonSearchButton.isEnabled = enabled
        
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

private extension ViewController {
    
    func subscribeToNotification(_ notification: NSNotification.Name, selector: Selector) {
        NotificationCenter.default.addObserver(self, selector: selector, name: notification, object: nil)
    }
    
    func unsubscribeFromAllNotifications() {
        NotificationCenter.default.removeObserver(self)
    }
}

