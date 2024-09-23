//
//  ViewController.swift
//  1111web
//
//  Created by 陳逸煌 on 2024/8/7.
//

import UIKit
import WebKit
import SwiftSoup


class ViewController: UIViewController, WKNavigationDelegate {
    
    var currentJobIndex: Int = 0
    
    var jobIDS: [String] = []
    
    var jobUrl: String = "https://www.104.com.tw/job/"
    
    var companyUrl: String = "www.104.com.tw/company/"
    
    var webView: WKWebView!
    
    var isAllPageComplete: Bool = false
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setupWebView()
        self.loadTo(url: "https://www.104.com.tw/company/a5h92m0")
        
    }
    
    func setupWebView() {
        let contentController = WKUserContentController()
        contentController.add(self, name: "callbackHandler")
        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        
        webView = WKWebView(frame: self.view.frame, configuration: config)
        webView.navigationDelegate = self
        self.view.addSubview(webView)
    }
    
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        checkIsLoad()
    }
    
    func loadTo(url: String) {
        var url = url
        if !url.contains("https://") {
            url.insert(contentsOf: "https://", at: url.startIndex)
        }
        
        if let url = URL(string: url) {
            let request = URLRequest(url: url)
            webView.load(request)
        } else {
            let fullURL = "https://www.104.com.tw" + url
            if let url = URL(string: fullURL) {
                let request = URLRequest(url: url)
                webView.load(request)
            }
        }
    }

    
    func checkIsLoad() {
        
        var jsCode = ""
         
        if !self.isAllPageComplete {
            jsCode =  """
             var specificElement = document.querySelector('div.joblist__container');
             if (specificElement && specificElement.textContent.trim() !== '') {
                 'Data is loaded';
             } else {
                 'Data is still loading';
             }
         """
        } else {
            jsCode = """
                   var h2Element = document.querySelector('h2');
                   if (h2Element && h2Element.textContent.includes('工作內容')) {
                       'Data is loaded';
                   } else {
                       'Data is still loading';
                   }
               """
        }
         
        
        
        
        webView.evaluateJavaScript(jsCode) { (result, error) in
              if let result = result as? String {
                  if result == "Data is loaded" {
                      print("Data is fully loaded")
                      self.getHTMLContent()
                  } else {
                      print("Data is still loading")
                      DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                          self.checkIsLoad()
                      }
                  }
              } else if let error = error {
                  print("Error: \(error.localizedDescription)")
              }
        }
        
    }
    
    func getHTMLContent() {
        webView.evaluateJavaScript("document.documentElement.outerHTML.toString()") { (html: Any?, error: Error?) in
            if let htmlString = html as? String {
                
                if self.webView.url?.absoluteString.contains(self.companyUrl) ?? false {
                    self.parseCompany(html: htmlString)
                    self.pressNextPageButton()
                } else if self.webView.url?.absoluteString.contains(self.jobUrl) ?? false {
                    self.parseJob(html: htmlString)
                    self.fetchJob()
                }
                
            } else if let error = error {
                print("Error: \(error.localizedDescription)")
            }
        }
    }
    func pressNextPageButton() {
        let jsCode = """
        (function() {
        
            // 正常的下一頁按鈕
            var elementA = document.querySelector('li.paging__item.d-inline-block.position-relative.text-center.mx-1.px-1 a.paging__link i.jb_icon_right[data-gtm-job="下一頁"]');
            var elementB = document.querySelector('a.btn.btn-sm.btn-text i.jb_icon_right');

            // Disabled 的下一頁按鈕
            var disabledElementA = document.querySelector('li.paging__item.disable a.paging__link i.jb_icon_right[data-gtm-job="下一頁"]');
            var disabledElementB = document.querySelector('a.btn.btn-sm.btn-text.disabled i.jb_icon_right');

            // 選擇下一頁按鈕，如果 disabled 的按鈕存在，則選擇 disabled 按鈕
            var element = elementA || elementB;
            var disabledElement = disabledElementA || disabledElementB;

            // 判斷按鈕是否 disabled
            if (disabledElement) {
                window.webkit.messageHandlers.callbackHandler.postMessage('All page complete');
            } else if (element) {
                if (element.offsetParent !== null) {
                    element.click();
                    
                    var checkRequestCompletion = function() {
                        var xhrs = window.performance.getEntriesByType('resource');
                        var allCompleted = true;

                        for (var i = 0; i < xhrs.length; i++) {
                            if (xhrs[i].responseEnd === 0) {
                                allCompleted = false;
                                break;
                            }
                        }

                        return allCompleted ? 'All requests completed' : 'Some requests still pending';
                    };

                    var checkInterval = setInterval(function() {
                        var status = checkRequestCompletion();
                        if (status === 'All requests completed') {
                            clearInterval(checkInterval);
                            window.webkit.messageHandlers.callbackHandler.postMessage('Next Page Request completed');
                        } else {
                            window.webkit.messageHandlers.callbackHandler.postMessage('Next Page Request uncompleted');
                        }
                    }, 1000);
                } else {
                    window.webkit.messageHandlers.callbackHandler.postMessage('Button is not visible');
                }
            } else {
                window.webkit.messageHandlers.callbackHandler.postMessage('Button not found');
            }
        })();
        """
        
        webView.evaluateJavaScript(jsCode) { (result, error) in
            if let error = error {
                print("JavaScript Error: \(error.localizedDescription)")
            }
        }
    }

    
    
    func fetchJob() {
        if self.currentJobIndex < self.jobIDS.count {
            self.loadTo(url: "\(jobUrl)\(jobIDS[self.currentJobIndex])")
            self.currentJobIndex+=1
        }
    }
    
    
    func parseCompany(html: String) {
        
        let targets = ["encodedjobno", "analysisurl"]
        
        
        do {
            let document = try SwiftSoup.parse(html)
            
            let joblistContainer: Element? = try document.select("div.joblist__container").first()
            
            if let container = joblistContainer {
                
                for target in targets {
                    let attrs: Elements = try container.select("div[\(target)]")
                    
                    if target == "encodedjobno" {
                        for attr in attrs {
                            let id = try attr.attr("\(target)")
                            if !jobIDS.contains(id) {
                                jobIDS.append(id)
                            }
                            
                        }
                    } else if target == "analysisurl" {
                        for attr in attrs {
                            let id = try attr.attr("\(target)").components(separatedBy: "/").last ?? ""
                            if !jobIDS.contains(id) {
                                jobIDS.append(id)
                            }
                            
                        }
                    }
                    
                  
                    
                }

                
                print(jobIDS)
                let set = Set(jobIDS)
                print(set.count)
            }
        } catch {
            print(error)
        }
    }
    
    func parseJob(html: String) {
        
        do {
            let document = try SwiftSoup.parse(html)
            
            
            let jobDescriptionDiv = try document.select("div.job-description-table").first()
            
            
            //職務類別
            if let jobCategory = try jobDescriptionDiv?.select("h3:contains(職務類別)").first() {
                
                if let jobNatureData = try jobCategory.parent()?.nextElementSibling()?.select("div.list-row__data").first()?.select("u") {
                    
                    let jobNatureText = try jobNatureData.text()
                    print("職務類別: \(jobNatureText)")
                }
            }
            
            
            //工作性質
            if let jobNatureTitle = try jobDescriptionDiv?.select("h3:contains(工作性質)").first() {
                
                if let jobNatureData = try jobNatureTitle.parent()?.nextElementSibling()?.select("div.list-row__data").first() {
                    
                    let jobNatureText = try jobNatureData.text()
                    print("工作性質: \(jobNatureText)")
                }
            }
            
            //上班地點
            if let jobWorkplaceTitle = try jobDescriptionDiv?.select("h3:contains(上班地點)").first() {
                
                if let jobWorkplace = try jobWorkplaceTitle.parent()?.nextElementSibling()?.select("div.job-address").select("span").first() {
                    
                    let jobWorkplaceText = try jobWorkplace.text()
                    print("上班地點: \(jobWorkplaceText)")
                }
            }
            
            
            let jobContentDiv = try document.select("div.job-description-table.row").last()
            
            // 工作內容
            if let jobContentText = try jobContentDiv?.select("p.job-description__content").first()?.text() {
                print("工作內容: \(jobContentText)")
            }
            
            let titles: [String] = [
                "遠端工作", "管理責任", "出差外派", "上班時段", "休假制度", "可上班日", "需求人數"
            ]
            
            for title in titles {
                if let h3title = try jobContentDiv?.select("h3:contains(\(title)").first() {
                    if let content = try h3title.parent()?.nextElementSibling()?.text() {
                        print("\(title): \(content.isEmpty ? "無" : content)")
                    }
                }
            }
            
            print("----")
        } catch {
            print(error)
        }
        
        
    }
    
    
}

extension ViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        print("收到的消息: \(message.body)")

        if message.name == "callbackHandler", let messageBody = message.body as? String {
            if messageBody == "Next Page Request completed" {
                self.checkIsLoad()
            } else if messageBody == "Next Page Request uncompleted" {
                print(messageBody)
            } else if messageBody == "All page complete" {
                self.isAllPageComplete = true
                self.fetchJob()
            }
        }
    }
}
