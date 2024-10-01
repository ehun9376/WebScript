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
    
    var companyUrl: String = "https://www.104.com.tw/company/"
    
    var webView: WKWebView!
    
    var isAllPageComplete: Bool = false
    
    let callBackHandlerName: String = "callbackHandler"
    
    var config: Config!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        do {
            self.config = try JSONDecoder().decode(Config.self, from: Config.jsonString!)
        } catch {
            print("Failed to decode JSON: \(error)")
        }
        
        
        self.setupWebView()
        self.loadTo(url: "https://www.104.com.tw/company/a5h92m0")
        
    }
    
    func setupWebView() {
        let contentController = WKUserContentController()
        contentController.add(self, name: callBackHandlerName)
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
            jsCode = config.checkIsAllPageCompleteJsCode.company
//            jsCode = "var specificElement = document.querySelector('div.joblist__container'); if (specificElement && specificElement.textContent.trim() !== '') {'Data is loaded'; } else { 'Data is still loading'; }"
        } else {
            
            jsCode = config.checkIsAllPageCompleteJsCode.job
//            "var h2Element = document.querySelector('h2');\nif (h2Element && h2Element.textContent.includes('工作內容')) {\n'Data is loaded';\n} else {\n'Data is still loading';\n}"

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
        let jsCode = config.pressNextButton
//        "(function() {\n// 查找 div.joblist__footer\nvar pageFooter = document.querySelector('div.joblist__footer');\n\n// 如果 pageFooter 沒有找到，直接發送 'All page complete' 消息\nif (!pageFooter) {\nwindow.webkit.messageHandlers.callbackHandler.postMessage('All page complete');\nreturn;\n}\n\n// 正常的下一頁按鈕\nvar normalNextButtonA = document.querySelector('li.paging__item.d-inline-block.position-relative.text-center.mx-1.px-1 a.paging__link i.jb_icon_right[data-gtm-job=\"下一頁\"]');\nvar normalNextButtonB = document.querySelector('a.btn.btn-sm.btn-text i.jb_icon_right');\n\n// Disabled 的下一頁按鈕\nvar disabledNextButtonA = document.querySelector('li.paging__item.disable a.paging__link i.jb_icon_right[data-gtm-job=\"下一頁\"]');\nvar disabledNextButtonB = document.querySelector('a.btn.btn-sm.btn-text.disabled i.jb_icon_right');\n\n// 選擇下一頁按鈕，如果 disabled 的按鈕存在，則選擇 disabled 按鈕\nvar nextButton = normalNextButtonA || normalNextButtonB;\nvar disabledNextButton = disabledNextButtonA || disabledNextButtonB;\n\n// 判斷按鈕是否 disabled\nif (disabledNextButton) {\nwindow.webkit.messageHandlers.callbackHandler.postMessage('All page complete');\n} else if (nextButton) {\nif (nextButton.offsetParent !== null) {\nnextButton.click();\n\nvar checkRequestCompletion = function() {\nvar xhrs = window.performance.getEntriesByType('resource');\nvar allCompleted = true;\n\nfor (var i = 0; i < xhrs.length; i++) {\nif (xhrs[i].responseEnd === 0) {\nallCompleted = false;\nbreak;\n}\n}\n\nreturn allCompleted ? 'All requests completed' : 'Some requests still pending';\n};\n\nvar checkInterval = setInterval(function() {\nvar status = checkRequestCompletion();\nif (status === 'All requests completed') {\nclearInterval(checkInterval);\nwindow.webkit.messageHandlers.callbackHandler.postMessage('Next Page Request completed');\n} else {\nwindow.webkit.messageHandlers.callbackHandler.postMessage('Next Page Request uncompleted');\n}\n}, 1000);\n} else {\nwindow.webkit.messageHandlers.callbackHandler.postMessage('Button is not visible');\n}\n} else {\nwindow.webkit.messageHandlers.callbackHandler.postMessage('All page complete');\n}\n})();"

        
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
        
        do {
            let document = try SwiftSoup.parse(html)
            
            let joblistContainer: Element? = try document.select(config.parseCompany.selector).first()
            
            if let container = joblistContainer {
                
                let subSelectors = config.parseCompany.subSelector
                
                for selector in subSelectors {
                    let attrs: Elements = try container.select(selector.selector)
                    
                    
                    for attr in attrs {
                        let id = try attr.attr(selector.target).components(separatedBy: "/").last ?? ""
                        if !jobIDS.contains(id) {
                            jobIDS.append(id)
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
            
            
            let jobDescriptionDiv = try document.select(config.parseJob.jobDescription.selector).first()
            
            
            //職務類別
            if let jobCategory = try jobDescriptionDiv?.select(config.parseJob.jobDescription.subSelector.jobCategory.selector).first() {
                
                if let jobNatureData = try jobCategory.parent()?.nextElementSibling()?.select(config.parseJob.jobDescription.subSelector.jobCategory.subSelector.selector) {
                    
                    let jobNatureText = try jobNatureData.text()
                    print("職務類別: \(jobNatureText)")
                }
            }
            
            
            //工作性質
            if let jobNatureTitle = try jobDescriptionDiv?.select(config.parseJob.jobDescription.subSelector.jobNature.selector).first() {
                
                if let jobNatureData = try jobNatureTitle.parent()?.nextElementSibling()?.select(config.parseJob.jobDescription.subSelector.jobNature.subSelector.selector).first() {
                    
                    let jobNatureText = try jobNatureData.text()
                    print("工作性質: \(jobNatureText)")
                }
            }
            
            //上班地點
            if let jobWorkplaceTitle = try jobDescriptionDiv?.select(config.parseJob.jobDescription.subSelector.jobWorkPlaceTitle.selector).first() {
                
                if let jobWorkplace = try jobWorkplaceTitle.parent()?.nextElementSibling()?.select(config.parseJob.jobDescription.subSelector.jobWorkPlaceTitle.subSelector.selector).first() {
                    
                    let jobWorkplaceText = try jobWorkplace.text()
                    print("上班地點: \(jobWorkplaceText)")
                }
            }
            
            
            let jobContentDiv = try document.select(config.parseJob.jobContent.selector).last()
            
            // 工作內容
            if let jobContentText = try jobContentDiv?.select(config.parseJob.jobContent.subSelector.selector).first()?.text() {
                print("工作內容: \(jobContentText)")
            }
            
            for subSelector in config.parseJob.jobContent.subSelectors {
                if let h3title = try jobContentDiv?.select(subSelector.selector).first() {
                    if let content = try h3title.parent()?.nextElementSibling()?.text() {
                        print("\(subSelector.title): \(content.isEmpty ? "無" : content)")
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

        if message.name == callBackHandlerName, let messageBody = message.body as? String {
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

// Root Model
struct Config: Codable {
    let companyURL: String
    let jobURL: String
    let pressNextButton: String
    let checkIsAllPageCompleteJsCode: CheckIsAllPageCompleteJsCode
    let parseCompany: ParseCompany
    let parseJob: ParseJob
    
    static let jsonString = """
{
    "companyURL": "https://www.104.com.tw/company/",
    "jobURL": "https://www.104.com.tw/job/",
    "pressNextButton": "(function() { var pageFooter = document.querySelector('div.joblist__footer');   if (!pageFooter) { window.webkit.messageHandlers.callbackHandler.postMessage('All page complete'); return; }   var normalNextButtonA = document.querySelector('li.paging__item.d-inline-block.position-relative.text-center.mx-1.px-1 a.paging__link i.jb_icon_right[data-gtm-job=\\"下一頁\\"]'); var normalNextButtonB = document.querySelector('a.btn.btn-sm.btn-text i.jb_icon_right');   var disabledNextButtonA = document.querySelector('li.paging__item.disable a.paging__link i.jb_icon_right[data-gtm-job=\\"下一頁\\"]'); var disabledNextButtonB = document.querySelector('a.btn.btn-sm.btn-text.disabled i.jb_icon_right');   var nextButton = normalNextButtonA || normalNextButtonB; var disabledNextButton = disabledNextButtonA || disabledNextButtonB;   if (disabledNextButton) { window.webkit.messageHandlers.callbackHandler.postMessage('All page complete'); } else if (nextButton) { if (nextButton.offsetParent !== null) { nextButton.click();  var checkRequestCompletion = function() { var xhrs = window.performance.getEntriesByType('resource'); var allCompleted = true;  for (var i = 0; i < xhrs.length; i++) { if (xhrs[i].responseEnd === 0) { allCompleted = false; break; } }  return allCompleted ? 'All requests completed' : 'Some requests still pending'; };  var checkInterval = setInterval(function() { var status = checkRequestCompletion(); if (status === 'All requests completed') { clearInterval(checkInterval); window.webkit.messageHandlers.callbackHandler.postMessage('Next Page Request completed'); } else { window.webkit.messageHandlers.callbackHandler.postMessage('Next Page Request uncompleted'); } }, 1000); } else { window.webkit.messageHandlers.callbackHandler.postMessage('Button is not visible'); } } else { window.webkit.messageHandlers.callbackHandler.postMessage('All page complete'); } })();",
    "checkIsAllPageCompleteJsCode": {
        "company": "var specificElement = document.querySelector('div.joblist__container'); if (specificElement && specificElement.textContent.trim() !== '') { 'Data is loaded'; } else { 'Data is still loading'; }",
        "job": "var h2Element = document.querySelector('h2'); if (h2Element && h2Element.textContent.includes('工作內容')) { 'Data is loaded'; } else { 'Data is still loading'; }"
    },
    "parseCompany": {
        "selector": "div.joblist__container",
        "subSelector": [
            {
                "selector": "div[encodedjobno]",
                "target": "encodedjobno"
            },
            {
                "selector": "div[analysisurl]",
                "target": "analysisurl"
            }
        ]
    },
    "parseJob": {
        "jobDescription": {
            "selector": "div.job-description-table",
            "subSelector": {
                "jobCategory": {
                    "selector": "h3:contains(職務類別)",
                    "subSelector": {
                        "selector": "div.list-row__data u"
                    }
                },
                "jobNature": {
                    "selector": "h3:contains(工作性質)",
                    "subSelector": {
                        "selector": "div.list-row__data"
                    }
                },
                "jobWorkPlaceTitle": {
                    "selector": "h3:contains(上班地點)",
                    "subSelector": {
                        "selector": "div.job-address span"
                    }
                }
            }
        },
        "jobContent": {
            "title": "工作內容",
            "selector": "div.job-description-table",
            "subSelector": {
                "title": "工作內容",
                "selector": "p.job-description__content"
            },
            "subSelectors": [
                {
                    "title": "遠端工作",
                    "selector": "h3:contains(遠端工作)"
                },
                {
                    "title": "管理責任",
                    "selector": "h3:contains(管理責任)"
                },
                {
                    "title": "出差外派",
                    "selector": "h3:contains(出差外派)"
                },
                {
                    "title": "上班時段",
                    "selector": "h3:contains(上班時段)"
                },
                {
                    "title": "休假制度",
                    "selector": "h3:contains(休假制度)"
                },
                {
                    "title": "可上班日",
                    "selector": "h3:contains(可上班日)"
                },
                {
                    "title": "需求人數",
                    "selector": "h3:contains(需求人數)"
                }
            ]
        }
    }
}
""".data(using: .utf8)
}

struct CheckIsAllPageCompleteJsCode: Codable {
    let company: String
    let job: String
}

struct ParseCompany: Codable {
    let selector: String
    let subSelector: [SubSelector]
}

struct SubSelector: Codable {
    let selector: String
    let target: String
}

struct ParseJob: Codable {
    let jobDescription: JobDescription
    let jobContent: JobContent
}

struct JobDescription: Codable {
    let selector: String
    let subSelector: JobDescriptionSubSelector
}

struct JobDescriptionSubSelector: Codable {
    let jobCategory: JobCategorySelector
    let jobNature: JobNatureSelector
    let jobWorkPlaceTitle: JobWorkPlaceTitleSelector
}

struct JobCategorySelector: Codable {
    let selector: String
    let subSelector: SubSelectorWithSelector
}

struct JobNatureSelector: Codable {
    let selector: String
    let subSelector: SubSelectorWithSelector
}


struct JobWorkPlaceTitleSelector: Codable {
    let selector: String
    let subSelector: SubSelectorWithSelector
}

struct SubSelectorWithSelector: Codable {
    let selector: String
}

struct JobContent: Codable {
    let title: String
    let selector: String
    let subSelector: JobContentSubSelector
    let subSelectors: [JobContentSubSelector]
}

struct JobContentSubSelector: Codable {
    let title: String
    let selector: String
}
