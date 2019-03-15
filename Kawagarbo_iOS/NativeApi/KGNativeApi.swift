//
//  KGNativeApiDelegate.swift
//  KawagarboExample
//
//  Created by 温一鸿 on 2018/9/26.
//  Copyright © 2018年 Moirig. All rights reserved.
//

import Foundation

public protocol KGNativeApiDelegate: NSObjectProtocol {
    
    var webViewController: KGWebViewController? { get set }
    
    var path: String { get }
    
    func perform(with parameters: [String: Any]?, complete: @escaping (_ response: KGNativeApiResponse) -> Void)
    
}

extension KGNativeApiDelegate where Self: KGNativeApi {
    
    func regist() {
        KGNativeApiManager.addNativeApi(self)
    }
    
}

public class KGNativeApi: NSObject {
    
    public weak var webViewController: KGWebViewController?
    
    public static func regist() {
        
        KGCanIUseApi().regist()
        KGGetSystemInfoApi().regist()
        
        KGNavigateToApi().regist()
        KGNavigateBackApi().regist()
        KGRedirectToApi().regist()
        KGReLaunchApi().regist()
        KGSwitchTabApi().regist()
        
        KGShowToastApi().regist()
        KGShowLoadingApi().regist()
        KGHideToastApi().regist()
        KGHideLoadingApi().regist()
        KGShowModalApi().regist()
        KGShowActionSheetApi().regist()
        
        KGShowNavigationBarLoadingApi().regist()
        KGSetNavigationBarTitleApi().regist()
        KGSetNavigationBarColorApi().regist()
        KGHideNavigationBarLoadingApi().regist()
        
        KGShowTabBarApi().regist()
        KGHideTabBarApi().regist()
        KGSetTabBarStyleApi().regist()
        KGSetTabBarItemApi().regist()
        KGShowTabBarRedDotApi().regist()
        KGHideTabBarRedDotApi().regist()
        KGSetTabBarBadgeApi().regist()
        KGRemoveTabBarBadgeApi().regist()
        
        KGPageScrollToApi().regist()
        
        KGOnKeyboardHeightChangeApi().regist()
        
        KGClearStorageApi().regist()
        KGGetStorageApi().regist()
        KGGetStorageInfoApi().regist()
        KGRemoveStorageApi().regist()
        KGSetStorageApi().regist()
        
        KGRequestApi().regist()
        KGDownloadFileApi().regist()
        KGUploadFileApi().regist()
        
        KGSaveImageToPhotosAlbumApi().regist()
    }
    
}
