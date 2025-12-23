// src/main/ets/view/QueueITViewManager.ts

import web_webview from '@ohos.web.webview';
import { QueueListener } from '../data/QueueListener';
import { QueueItEngineOptions, QueueTryPassResult, QueuePassedInfo } from '../data/QueueModels';
import { UriOverrider, UriOverrideResult, UriOverrideResponse } from '../utils/UriOverrider';
import { Logger } from '../utils/Logger';
import { QueueError } from '../data/QueueError';
import { QueueItEngine } from '../main/QueueItEngine';
import { common, Want } from '@kit.AbilityKit';
import { UserIdManager } from '../utils/UserIdManager';

export class QueueItViewManager {
    private static readonly TAG = "QueueITViewManager";
    // --- State for UI Binding ---
    public webviewController: web_webview.WebviewController;
    public showWebView: boolean = false;
    public isLoading: boolean = false;
    // --- Internal Properties ---
    private uriOverrider: UriOverrider;
    private queueListener: QueueListener;
    private navPathStack: NavPathStack;
    private options: QueueItEngineOptions;
    private currentQueueUrl: string | null = null;
    private currentTargetUrl: string | null = null;
    private userId: string | null = null;
    private engineInstance?: QueueItEngine;
    private context: common.UIAbilityContext | common.ApplicationContext | common.Context;

    constructor(
        context: common.UIAbilityContext | common.ApplicationContext | common.Context,
        queueListener: QueueListener,
        navPathStack: NavPathStack,
        options: QueueItEngineOptions,
        engineInstance?: QueueItEngine
    ) {
        this.context = context;
        this.queueListener = queueListener;
        this.navPathStack = navPathStack;
        this.options = options;
        this.engineInstance = engineInstance;
        this.webviewController = new web_webview.WebviewController();
        this.uriOverrider = new UriOverrider();
    }

    // --- Public methods to control the View/State ---

    public async showQueue(queueTryPassResult: QueueTryPassResult): Promise<void> {
        if (!queueTryPassResult.queueUrl) {
            Logger.error(QueueItViewManager.TAG, "Cannot show queue, Queue URL is missing.");
            this.queueListener.onError(QueueError.INVALID_RESPONSE, "Missing Queue URL for display");
            return;
        }

        this.currentQueueUrl = queueTryPassResult.queueUrl;
        this.currentTargetUrl = queueTryPassResult.targetUrl;
        this.userId = await UserIdManager.getUserId();
        this.uriOverrider.setQueueHostUrl(this.currentQueueUrl);
        this.uriOverrider.setTargetUrl(this.currentTargetUrl);
        this.uriOverrider.setUserId(this.userId);

        Logger.debug(QueueItViewManager.TAG, `Preparing to show queue: ${this.currentQueueUrl}`);
        this.queueListener.onQueueViewWillOpen();

        setTimeout(() => {
            this.isLoading = true;
            this.showWebView = true;
            Logger.info(QueueItViewManager.TAG, `Loading Queue URL after delay: ${this.currentQueueUrl}`);
            this.navPathStack.pushPath({
                name: 'QueueView'
            });
        }, this.options.viewDelayMs);
    }

    public async loadUrl(): Promise<void> {
        try {
            this.isLoading = true;
            this.showWebView = true;
            this.webviewController.loadUrl(this.currentQueueUrl!);

        } catch (loadError) {
            Logger.error(QueueItViewManager.TAG, `Error calling loadUrl: ${loadError.message}`);
            this.queueListener.onError(QueueError.INVALID_RESPONSE, `Failed to load queue URL: ${loadError.message}`);
            this.isLoading = false;
            this.showWebView = false;
        }
    }

    public hideQueue(): void {
        Logger.debug(QueueItViewManager.TAG, "Hiding queue view");
        if (this.showWebView) {
            try {
                this.webviewController.stop();
                this.webviewController.loadUrl("about:blank");
                this.navPathStack.pop();
            } catch (e) {
                Logger.warn(QueueItViewManager.TAG, `Error stopping/clearing webview: ${e.message}`);
            } finally {
                this.showWebView = false;
                this.isLoading = false;
                this.currentQueueUrl = null;
                this.currentTargetUrl = null;
            }
        }
    }

    // --- Handler methods called FROM the <Web> component's events ---

    /**
     * Handles URL loading interception logic. Called by <Web onUrlLoadIntercept={...}>.
     * @param url The URL being loaded.
     * @returns True to prevent default loading, False to allow it.
     */
    public handleUrlIntercept(url: string | undefined | null): boolean {
        if (!url) {
            Logger.warn(QueueItViewManager.TAG, "handleUrlIntercept called without URL.");
            return false; // Allow default handling if URL is missing
        }
        Logger.debug(QueueItViewManager.TAG, `handleUrlIntercept : before handleNavigationRequest ${url}`);
        const result: UriOverrideResponse = this.uriOverrider.handleNavigationRequest(url);

        switch (result.action) {
            case UriOverrideResult.LOAD_IN_WEBVIEW:
                Logger.debug(QueueItViewManager.TAG,
                    `LOAD_IN_WEBVIEW, Intercept: Allow load ${result.modifiedUrl || url}`);
                this.queueListener.onQueueUrlChanged?.(result.modifiedUrl || url);
                Logger.debug(QueueItViewManager.TAG,
                    `LOAD_IN_WEBVIEW, Intercept : result.modifiedUrl ${result.modifiedUrl}`);
                Logger.debug(QueueItViewManager.TAG, `LOAD_IN_WEBVIEW, Intercept : url ${url}`);
                if (result.modifiedUrl && result.modifiedUrl !== url) {
                    try {
                        this.webviewController.loadUrl(result.modifiedUrl);
                    } catch (e) {
                        Logger.error(QueueItViewManager.TAG, `Error loading rewritten URL: ${e.message}`);
                    }
                    return true;
                }
                return false;

            case UriOverrideResult.PASSED:
                Logger.info(QueueItViewManager.TAG, `Intercept: Queue Passed. Token: ${result.queueItToken}`);
                this.hideQueue();
                let queuePassedInfo = new QueuePassedInfo(result.queueItToken ?? null);
                this.queueListener.onQueuePassed(queuePassedInfo);
                return true;

            case UriOverrideResult.CLOSE:
                Logger.info(QueueItViewManager.TAG, "Intercept: Close requested.");
                this.hideQueue();
                this.queueListener.onWebViewClosed?.();
                return true;

            case UriOverrideResult.RESTART_SESSION:
                Logger.info(QueueItViewManager.TAG, "Intercept: Session Restart requested.");
                this.hideQueue();
                this.queueListener.onSessionRestart?.(this.engineInstance);
                return true;

            case UriOverrideResult.OPEN_EXTERNAL:
                Logger.info(QueueItViewManager.TAG, `Intercept: Open external ${url}`);
                this.tryOpenExternalUrl(url);
                return true;

            case UriOverrideResult.BLOCK:
                Logger.debug(QueueItViewManager.TAG, `Intercept: Block load ${url}`);
                return true;

            default:
                Logger.debug(QueueItViewManager.TAG, `Intercept: Default load ${url}`);
                return false;
        }
    }

    /** Called by <Web onPageBegin={...}> */
    public handlePageBegin(event: OnPageBeginEvent): void {
        this.isLoading = true;
        Logger.debug(QueueItViewManager.TAG, `onPageBegin: ${event?.url}`);
    }

    /** Called by <Web onPageEnd={...}> */
    public handlePageEnd(event: OnPageEndEvent): void {
        this.isLoading = false;
        Logger.debug(QueueItViewManager.TAG, `onPageEnd: ${event?.url}`);
    }

    /** Called by <Web onErrorReceive={...}> */
    public handleErrorReceive(event: OnErrorReceiveEvent): void {
        this.isLoading = false;
        const error = event?.error;
        const req = event?.request;
        const errorCode = error?.getErrorCode() ?? 'Unknown';
        const errorInfo = error?.getErrorInfo() ?? 'Unknown WebView error';
        const requestUrl = req?.getRequestUrl() ?? 'N/A';
        Logger.error(QueueItViewManager.TAG, `onErrorReceive: Code ${errorCode} Msg: ${errorInfo} URL: ${requestUrl}`);
    }

    /** Called by <Web onHttpErrorReceive={...}> */
    public handleHttpErrorReceive(event: OnHttpErrorReceiveEvent): void {
        this.isLoading = false;
        const req = event?.request;
        const responseCode = event?.response?.getResponseCode() ?? 'N/A';
        const responseMessage = event?.response?.getReasonMessage() ?? 'N/A';
        const requestUrl = req?.getRequestUrl() ?? 'N/A';
        Logger.error(QueueItViewManager.TAG,
            `onHttpErrorReceive: Code ${responseCode} Msg: ${responseMessage} URL: ${requestUrl}`);
    }

    /** Called by <Web onSslErrorReceive={...}> */
    public handleSslErrorReceive(event: OnSslErrorEventReceiveEvent): void {
        this.isLoading = false;
        const error = event?.error;
        const sslErrorCode = error.toString() ?? 'Unknown SSL Error';
        Logger.error(QueueItViewManager.TAG, `onSslErrorReceive: ${sslErrorCode}`);
        this.queueListener.onError(QueueError.SSL_ERROR, `SSL Error: ${sslErrorCode}`);
        this.hideQueue();
    }

    public canWebViewGoBack(): boolean {
        try {
            return this.webviewController.accessBackward();
        } catch (e) {
            Logger.error(QueueItViewManager.TAG, `Error checking accessBackward: ${e.message}`);
            return false;
        }
    }

    public webViewGoBack(): void {
        try {
            if (this.canWebViewGoBack()) {
                this.webviewController.backward();
            } else {
                Logger.warn(QueueItViewManager.TAG, "webViewGoBack called but cannot go back.");
            }
        } catch (e) {
            Logger.error(QueueItViewManager.TAG, `Error calling backward: ${e.message}`);
        }
    }

    public handleBackPress(): boolean {
        if (!this.showWebView) {
            return false;
        }
        if (this.options.disableBackButtonFromWR) {
            Logger.debug(QueueItViewManager.TAG, "Back button disabled via options. Consuming event.");
            return true;
        }
        return false;
    }

    // --- Utility Methods (remain the same) ---
    private async tryOpenExternalUrl(urlString: string): Promise<void> {
        Logger.warn(QueueItViewManager.TAG, `External URL opening not fully implemented for: ${urlString}`);
        try {
            let context = this.context as common.UIAbilityContext;
            let want: Want = {
                uri: urlString.toString(),
                action: 'ohos.want.action.viewData'
            }
            context.startAbility(want)
        } catch (error) {
            Logger.error(QueueItViewManager.TAG,
                `Failed to start ability for external URL ${urlString}: ${error.message}`);
        }
    }
}
