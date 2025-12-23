// src/main/ets/components/QueueView.ets
import web_webview from '@ohos.web.webview'; // Import is still needed for types used in handlers if any
import { QueueItViewManager } from '../view/QueueItViewManager';
import { Logger } from '../utils/Logger';
import { UserAgentManager } from '../utils/UserAgentManager';
import { BusinessError } from '@kit.BasicServicesKit';

@Component
export struct QueueView {
    // Use @Link to bind to the viewManager instance held in the parent's @State
    @Link viewManager: QueueItViewManager;
    private static readonly TAG = "QueueView";

    async aboutToAppear() {
        Logger.debug(QueueView.TAG, "QueueView aboutToAppear");
    }

    aboutToDisappear() {
        Logger.debug(QueueView.TAG, "QueueView aboutToDisappear");
    }

    build() {
        NavDestination() {
            Column() {
                if (this.viewManager.isLoading) {
                    LoadingProgress()
                        .width(50).height(50)
                        .color(Color.Blue)
                        .margin({ top: 20 })
                }

                Web({
                    controller: this.viewManager.webviewController,
                    src: ""
                })
                    .onControllerAttached(() => {
                        try {
                            let userAgent = this.viewManager.webviewController.getUserAgent();
                            let constructedUA = UserAgentManager.getUserAgent(userAgent);
                            this.viewManager.webviewController.setCustomUserAgent(constructedUA);
                        } catch (error) {
                            Logger.error(QueueView.TAG, `ErrorCode: ${(error as BusinessError).code},  Message: ${(error as BusinessError).message}`);
                        }
                        this.viewManager.loadUrl();
                    })
                    // --- Attributes ---
                    .javaScriptAccess(true)
                    .width('100%')
                    .height('100%')
                    // --- Event Listeners ---
                    .onLoadIntercept((event) => {
                        if (event.data.isMainFrame() == true) {
                            const url = event.data.getRequestUrl();
                            return this.viewManager.handleUrlIntercept(url);
                        }
                        return false
                    })
                    .onPageBegin((event) => {
                        this.viewManager.handlePageBegin(event);
                    })
                    .onPageEnd((event) => {
                        this.viewManager.handlePageEnd(event);
                    })
                    .onErrorReceive((event) => {
                        this.viewManager.handleErrorReceive(event);
                    })
                    .onHttpErrorReceive((event) => {
                        this.viewManager.handleHttpErrorReceive(event);
                    })
                    .onSslErrorEventReceive((event) => {
                        this.viewManager.handleSslErrorReceive(event);
                    })
                    .onAlert((event) => {
                        if (event) {
                            this.getUIContext().showAlertDialog({
                                title: event.url,
                                message: event.message,
                                primaryButton: {
                                    value: $r('app.string.ok_button'),
                                    action: () => {
                                        event.result.handleConfirm();
                                    }
                                }
                            })
                        }
                        return true;
                    })
            }
            .width('100%')
            .height('100%')
            .visibility(this.viewManager.showWebView ? Visibility.Visible : Visibility.None)

        }
        .hideTitleBar(true)
        .onBackPressed(() => {
            if (this.viewManager && this.viewManager.showWebView) {
                return this.viewManager.handleBackPress();
            }
            return false;
        })
    }
}
