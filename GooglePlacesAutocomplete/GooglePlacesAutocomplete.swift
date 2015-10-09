//
//  GooglePlacesAutocomplete.swift
//  GooglePlacesAutocomplete
//
//  Created by Howard Wilson on 10/02/2015.
//  Copyright (c) 2015 Howard Wilson. All rights reserved.
//

import UIKit

public enum PlaceType: CustomStringConvertible {
  case All
  case Geocode
  case Address
  case Establishment
  case Regions
  case Cities

  public var description : String {
    switch self {
      case .All: return ""
      case .Geocode: return "geocode"
      case .Address: return "address"
      case .Establishment: return "establishment"
      case .Regions: return "(regions)"
      case .Cities: return "(cities)"
    }
  }
}

public class Place: NSObject {
  public let id: String
  public let desc: String
  public var apiKey: String?
    public var cidade: String?

  override public var description: String {
    get { return desc }
  }

  public init(id: String, description: String) {
    self.id = id
    self.desc = description
  }

  public convenience init(prediction: [String: AnyObject], apiKey: String?) {
    self.init(
      id: prediction["place_id"] as! String,
      description: prediction["description"] as! String
    )

    self.apiKey = apiKey
  }

  /**
    Call Google Place Details API to get detailed information for this place
  
    Requires that Place#apiKey be set
  
    :param: result Callback on successful completion with detailed place information
  */
  public func getDetails(result: PlaceDetails -> ()) {
    GooglePlaceDetailsRequest(place: self).request(result)
  }
}

public class PlaceDetails: CustomStringConvertible {
  public let name: String
  public let latitude: Double
  public let longitude: Double
  public let raw: [String: AnyObject]

  public init(json: [String: AnyObject]) {
    let result = json["result"] as! [String: AnyObject]
    let geometry = result["geometry"] as! [String: AnyObject]
    let location = geometry["location"] as! [String: AnyObject]

    self.name = result["name"] as! String
    self.latitude = location["lat"] as! Double
    self.longitude = location["lng"] as! Double
    self.raw = json
  }

  public var description: String {
    return "PlaceDetails: \(name) (\(latitude), \(longitude))"
  }
}

@objc public protocol GooglePlacesAutocompleteDelegate {
  optional func placesFound(places: [Place])
  optional func placeSelected(place: Place)
  optional func placeViewClosed(place: Place)
}

// MARK: - GooglePlacesAutocomplete
public class GooglePlacesAutocomplete: UINavigationController {
  public var gpaViewController: GooglePlacesAutocompleteContainer!
  public var closeButton: UIBarButtonItem!

  // Proxy access to container navigationItem
  public override var navigationItem: UINavigationItem {
    get { return gpaViewController.navigationItem }
  }

  public var placeDelegate: GooglePlacesAutocompleteDelegate? {
    get { return gpaViewController.delegate }
    set { gpaViewController.delegate = newValue }
  }

  public convenience init(apiKey: String, placeType: PlaceType = .All) {
    let gpaViewController = GooglePlacesAutocompleteContainer(
      apiKey: apiKey,
      placeType: placeType
    )

    self.init(rootViewController: gpaViewController)
    self.gpaViewController = gpaViewController

    closeButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Stop, target: self, action: "close")
    closeButton.style = UIBarButtonItemStyle.Done

    gpaViewController.navigationItem.leftBarButtonItem = closeButton
    if placeType.description == "address" {
        gpaViewController.navigationItem.title = "Endereço"
    }
    else {
        gpaViewController.navigationItem.title = "Cidade"
    }
    gpaViewController.navigationController?.navigationBar.barTintColor = UIColor.whiteColor()
    //gpaViewController.navigationController?.setNavigationBarHidden(true, animated: true)
  }

  func close() {
    //placeDelegate?.placeViewClosed?(Place())
    dismissViewControllerAnimated(true, completion: nil)
  }

  public func reset() {
    gpaViewController.searchBar.text = ""
    gpaViewController.searchBar(gpaViewController.searchBar, textDidChange: "")
  }
}

// MARK: - GooglePlacesAutocompleteContainer
public class GooglePlacesAutocompleteContainer: UIViewController {
  @IBOutlet public weak var searchBar: UISearchBar!
  @IBOutlet weak var tableView: UITableView!
  @IBOutlet weak var topConstraint: NSLayoutConstraint!
    @IBOutlet weak var container: UIView!
    
    var originalController : GooglePlacesAutocompleteContainer?

  var delegate: GooglePlacesAutocompleteDelegate?
  var apiKey: String?
  var places = [Place]()
  var placeType: PlaceType = .All
    var cidade: String?

  convenience init(apiKey: String, placeType: PlaceType = .All) {
    let bundle = NSBundle(forClass: GooglePlacesAutocompleteContainer.self)

    self.init(nibName: "GooglePlacesAutocomplete", bundle: bundle)
    self.apiKey = apiKey
    self.placeType = placeType
  }

  deinit {
    NSNotificationCenter.defaultCenter().removeObserver(self)
  }

  override public func viewWillLayoutSubviews() {
    topConstraint.constant = topLayoutGuide.length
  }

  override public func viewDidLoad() {
    super.viewDidLoad()
    
    container.layer.cornerRadius = 6.0
    container.clipsToBounds = true
    
    let labelTitle = UILabel(frame: CGRectZero)
    labelTitle.textAlignment = NSTextAlignment.Center
    labelTitle.textColor = UIColor.whiteColor()
    
    if placeType.description == "address" {
        labelTitle.text = "Endereço"
    }
    else {
        labelTitle.text = "Cidade"
    }
    
    var completedNavString = NSMutableAttributedString()
    
    completedNavString = NSMutableAttributedString(string: labelTitle.text!, attributes: [NSFontAttributeName:UIFont(name: "HelveticaNeue-Thin", size: 25.0)!])
    
    let navLabel = UILabel()
    navLabel.attributedText = completedNavString
    navLabel.sizeToFit()
    navLabel.textColor = UIColor.whiteColor()
    
    
    self.navigationItem.titleView = navLabel
    
    self.tableView.separatorInset = UIEdgeInsetsZero
    self.tableView.layoutMargins = UIEdgeInsetsZero;
    
    let footer : UIView = UIView()
    footer.frame = CGRectZero
    self.tableView.tableFooterView = footer

    NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWasShown:", name: UIKeyboardDidShowNotification, object: nil)
    NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillBeHidden:", name: UIKeyboardWillHideNotification, object: nil)

    searchBar.becomeFirstResponder()
    tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: "Cell")
  }
    
    @IBAction func close() {
        super.dismissViewControllerAnimated(true, completion: nil)
    }

  func keyboardWasShown(notification: NSNotification) {
    if isViewLoaded() && view.window != nil {
      let info: Dictionary = notification.userInfo!
      let keyboardSize: CGSize = (info[UIKeyboardFrameBeginUserInfoKey]?.CGRectValue.size)!
      let contentInsets = UIEdgeInsetsMake(0.0, 0.0, keyboardSize.height, 0.0)

      tableView.contentInset = contentInsets;
      tableView.scrollIndicatorInsets = contentInsets;
    }
  }

  func keyboardWillBeHidden(notification: NSNotification) {
    if isViewLoaded() && view.window != nil {
      self.tableView.contentInset = UIEdgeInsetsZero
      self.tableView.scrollIndicatorInsets = UIEdgeInsetsZero
    }
  }
}

// MARK: - GooglePlacesAutocompleteContainer (UITableViewDataSource / UITableViewDelegate)
extension GooglePlacesAutocompleteContainer: UITableViewDataSource, UITableViewDelegate {
  public func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return places.count
  }

  public func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath) as UITableViewCell

    // Get the corresponding candy from our candies array
    let place = self.places[indexPath.row]
    
    cell.layoutMargins = UIEdgeInsetsZero
    cell.separatorInset = UIEdgeInsetsZero
    cell.backgroundColor = UIColor(red: 230/255, green: 230/255, blue: 230/255, alpha: 1)

    // Configure the cell
    cell.textLabel!.text = place.description
    cell.accessoryType = UITableViewCellAccessoryType.DisclosureIndicator
    
    return cell
  }

  public func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
    
    
    if (cidade == nil) {
        delegate?.placeSelected?(self.places[indexPath.row])
        let gpaViewController2 = GooglePlacesAutocompleteContainer(
            apiKey: apiKey!,
            placeType: .Address
        )
        
        let lugar = self.places[indexPath.row] as Place
        
        gpaViewController2.cidade = lugar.desc
        gpaViewController2.originalController = self
        
        self.navigationController?.pushViewController(gpaViewController2, animated: true)
    }
    else {
        self.navigationController?.popToRootViewControllerAnimated(true);
        originalController!.delegate?.placeViewClosed?(self.places[indexPath.row])
    }
  }
}

// MARK: - GooglePlacesAutocompleteContainer (UISearchBarDelegate)
extension GooglePlacesAutocompleteContainer: UISearchBarDelegate {
  public func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
    if (searchText == "") {
      self.places = []
      tableView.hidden = true
    } else {
      getPlaces(searchText.stringByReplacingOccurrencesOfString(" ", withString: "%20"))
    }
  }

  /**
    Call the Google Places API and update the view with results.

    :param: searchString The search query
  */
  private func getPlaces(var searchString: String) {
    
    if self.cidade != nil {
        self.cidade = self.cidade!.stringByReplacingOccurrencesOfString(" ", withString: "%20")
        searchString = "\(self.cidade!), \(searchString)"
    }

    GooglePlacesRequestHelpers.doRequest(
      "https://maps.googleapis.com/maps/api/place/autocomplete/json",
      params: [
        "input": searchString.stringByReplacingOccurrencesOfString(" ", withString: "%20"),
        "types": placeType.description,
        "language": "pt_BR", // Choose Your Language ***
        "key": apiKey! ?? ""
      ]
    ) { json in
      if let predictions = json["predictions"] as? Array<[String: AnyObject]> {
        self.places = predictions.map { (prediction: [String: AnyObject]) -> Place in
          return Place(prediction: prediction, apiKey: self.apiKey)
        }

        self.tableView.reloadData()
        self.tableView.hidden = false
        self.delegate?.placesFound?(self.places)
      }
    }
  }
}

// MARK: - GooglePlaceDetailsRequest
class GooglePlaceDetailsRequest {
  let place: Place

  init(place: Place) {
    self.place = place
  }

  func request(result: PlaceDetails -> ()) {
    GooglePlacesRequestHelpers.doRequest(
      "https://maps.googleapis.com/maps/api/place/details/json",
      params: [
        "placeid": place.id,
        "key": place.apiKey ?? ""
      ]
    ) { json in
      result(PlaceDetails(json: json as! [String: AnyObject]))
    }
  }
}

// MARK: - GooglePlacesRequestHelpers
class GooglePlacesRequestHelpers {
  /**
  Build a query string from a dictionary

  :param: parameters Dictionary of query string parameters
  :returns: The properly escaped query string
  */
  private class func query(parameters: [String: AnyObject]) -> String {
    var components: [(String, String)] = []
    var stringParametros = ""
    //for key in sort(Array(parameters.keys), <) {
    for key in Array(parameters.keys).sort(<) {
      let value: AnyObject! = parameters[key]
      components += [(escape(key), escape("\(value)"))]
        stringParametros += "&\(key)=\(value)"
    }
    
    return stringParametros
    
    //return components.map{"\($0)=\($1)"}.joinWithSeparator("&")
    
    

    //return join("&", components.map{"\($0)=\($1)"} as [String])
  }

  private class func escape(string: String) -> String {
    //let legalURLCharactersToBeEscaped: CFStringRef = ":/?&=;+!@#$()',*"
    //return CFURLCreateStringByAddingPercentEscapes(nil,  string, nil, legalURLCharactersToBeEscaped, CFStringBuiltInEncodings.UTF8.rawValue) as String
    
    
    return String().stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())!
  }

  private class func doRequest(url: String, params: [String: String], success: NSDictionary -> ()) {
    let request = NSMutableURLRequest(
      URL: NSURL(string: "\(url)?\(query(params))")!
    )

    let session = NSURLSession.sharedSession()
    let task = session.dataTaskWithRequest(request) { data, response, error in
      self.handleResponse(data, response: response as? NSHTTPURLResponse, error: error, success: success)
    }

    task.resume()
  }

  private class func handleResponse(data: NSData!, response: NSHTTPURLResponse!, error: NSError!, success: NSDictionary -> ()) {
    if let error = error {
      print("GooglePlaces Error: \(error.localizedDescription)")
      return
    }

    if response == nil {
      print("GooglePlaces Error: No response from API")
      return
    }

    if response.statusCode != 200 {
      print("GooglePlaces Error: Invalid status code \(response.statusCode) from API")
      return
    }

    //let serializationError: NSError?
    let json: NSDictionary = try! NSJSONSerialization.JSONObjectWithData(
      data,
      options: NSJSONReadingOptions.MutableContainers
      ) as! NSDictionary

//    if let error = serializationError {
//      print("GooglePlaces Error: \(error.localizedDescription)")
//      return
//    }

    if let status = json["status"] as? String {
      if status != "OK" {
        print("GooglePlaces API Error: \(status)")
        return
      }
    }

    // Perform table updates on UI thread
    dispatch_async(dispatch_get_main_queue(), {
      UIApplication.sharedApplication().networkActivityIndicatorVisible = false

      success(json)
    })
  }
}
