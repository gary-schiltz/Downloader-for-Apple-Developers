//
//  DownloaderViewController.swift
//  DeveloperToolsDownloader
//
//  Created by Vineet Choudhary on 17/02/20.
//  Copyright © 2020 Developer Insider. All rights reserved.
//

import Cocoa
import WebKit

class DownloaderViewController: NSViewController {
    
    //MARK: - IBOutlets
    @IBOutlet weak var webView: WKWebView!
    @IBOutlet weak var statusLabel: NSTextField!
    @IBOutlet weak var downloadSourceTableView: NSTableView!
    @IBOutlet weak var downloadProgressTableView: NSTableView!
    
    //MARK: - Properties
    private var downloadSource: DownloadSource = .tools
    private var downloadSourceTableViewHandler: DownloadSourceTableViewHandler!
    private var downloadProgressTableViewHandler: DownloadProgressTableViewHandler!
    private var downloadProcessManager = DownloadProcessManager.shared
    
    //MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        //Download Service TableView
        downloadSourceTableViewHandler = DownloadSourceTableViewHandler(tableView: downloadSourceTableView)
        
        //Handle downnload service selection change
        downloadSourceTableViewHandler.selectionChange { [weak self] (downloadSource) in
            guard let self = self else {
                return;
            }
            //Set Download URL
            self.downloadSource = downloadSource;
            
            //Load Download URL to WebView
            let url = URL(string: downloadSource.url)!
            self.webView.navigationDelegate = self
            self.webView.load(URLRequest(url: url))
            self.updateStatus(text: NSLocalizedString("InitialStatus", comment: ""))
            self.updateStatus(text: String(format: NSLocalizedString("SwitchingSource", comment: ""), downloadSource.title))
        }
        
        //Downnload Progress TableView
        downloadProgressTableViewHandler = DownloadProgressTableViewHandler(tableView: downloadProgressTableView)
        
        //Setup download process manager
        downloadProcessManager.delegate = self
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    @IBAction func statusTapAction(_ sender: NSClickGestureRecognizer) {
        performSegue(withIdentifier: "ShowLogsViewController", sender: nil)
    }
}

//MARK: - Download Helper
extension DownloaderViewController {
    fileprivate func startDownload(fileURL: String?) {
        downloadProcessManager.startDownload(source: downloadSource, fileURL: fileURL)
    }
    
    fileprivate func updateStatus(text: String) {
        if !text.isEmpty {
            self.statusLabel.stringValue = text
        }
    }
    
    fileprivate func checkDownloadAuthToken() {
        DispatchQueue.main.asyncAfter(deadline: .now()+4) { [weak self] in
            guard let self = self else {
                return;
            }
            
            self.webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [unowned self] (cookie) in
                if let downloadAuthToken = cookie.first(where: {$0.name == CookieName.downloadAuthToken.rawValue})?.value {
                    DownloadProcessManager.shared.setDownloadAuthToken(token: downloadAuthToken)
                    self.updateStatus(text: NSLocalizedString("DownloadAuthTokenSuccess", comment: ""))
                } else {
                    self.updateStatus(text: NSLocalizedString("DownloadAuthTokenNotFound", comment: ""))
                }
            }
        }
    }
}

//MARK: - WebKit Navigation Delegate
extension DownloaderViewController : WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let pathExtension = navigationAction.request.url?.pathExtension.lowercased(),
            let _ = SupportedExtension(rawValue: pathExtension) {
            let downloadFileURL = navigationAction.request.url?.absoluteString
            self.startDownload(fileURL: downloadFileURL)
            decisionHandler(.cancel)
        }
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        updateStatus(text: error.localizedDescription)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let currentURL = webView.url?.absoluteString else {
            updateStatus(text: NSLocalizedString("CommonError", comment: ""))
            return;
        }
        if currentURL.lowercased().contains(AppleDomains.auth.rawValue.lowercased()) {
            updateStatus(text: NSLocalizedString("LoginRequired", comment: ""))
        } else if currentURL.lowercased().contains(DownloadSource.tools.url.lowercased()) {
            updateStatus(text: NSLocalizedString("CheckingDownloadAuthToken", comment: ""))
            checkDownloadAuthToken()
        } else {
            updateStatus(text: NSLocalizedString("AllSet", comment: ""))
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        updateStatus(text: error.localizedDescription)
    }
}

//MARK: - DownloadProcessManager Delegate
extension DownloaderViewController: DownloadProcessDelegate {
    func downloadStart(url: String) {
        Logger.downloadStart(url: url)
    }
    
    func downloadFinish(url: String) {
        Logger.downloadFinish(url: url)
    }
    
    func outputStream(output: String) {
        updateStatus(text: output)
    }
}
