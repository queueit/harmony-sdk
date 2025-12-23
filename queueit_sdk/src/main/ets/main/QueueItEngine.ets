// src/main/ets/main/QueueItEngine.ts
import { QueueListener } from '../data/QueueListener';
import {
    QueueItEngineOptions,
    QueuePassedInfo,
    QueueDisabledInfo,
    QueueTryPassResult,
    RedirectType
} from '../data/QueueModels';
import { QueueItWaitingRoomProvider } from '../providers/QueueItWaitingRoomProvider';
import { QueueItViewManager } from '../view/QueueItViewManager';
import { QueueError } from '../data/QueueError';
import { Logger } from '../utils/Logger';

// Assuming getApplicationContext() is available or passed in
import common from '@ohos.app.ability.common';
import { VersionManager } from '../utils/VersionManager';


export class QueueItEngine {
    private static readonly TAG = "QueueItEngine";
    private provider: QueueItWaitingRoomProvider;
    private viewManager: QueueItViewManager;
    private options: QueueItEngineOptions;
    private queueListener: QueueListener;
    private navPathStack: NavPathStack;
    private context: common.UIAbilityContext | common.ApplicationContext | common.Context;
    private customerId: string;
    private eventOrAliasId: string;

    constructor(
        context: common.UIAbilityContext | common.ApplicationContext | common.Context,
        customerId: string,
        eventOrAliasId: string,
        queueListener: QueueListener,
        navPathStack: NavPathStack,
        layoutName?: string,
        language?: string,
        options?: Partial<QueueItEngineOptions>
    ) {
        this.customerId = customerId;
        this.eventOrAliasId = eventOrAliasId;
        this.context = context;
        this.queueListener = queueListener;
        this.navPathStack = navPathStack;
        // Merge default and provided options
        this.options = new QueueItEngineOptions();
        if (options) {
            if (options.disableBackButtonFromWR != null) {
                this.options.disableBackButtonFromWR = options.disableBackButtonFromWR
            }
            if (options.webViewUserAgent != null) {
                this.options.webViewUserAgent = options.webViewUserAgent
            }
            if (options.viewDelayMs != null) {
                this.options.viewDelayMs = options.viewDelayMs
            }
        }

        this.provider =
            new QueueItWaitingRoomProvider(this.context, this.customerId, this.eventOrAliasId, layoutName, language);

        this.viewManager = new QueueItViewManager(this.context, this.queueListener, this.navPathStack, this.options, this);
        Logger.info(QueueItEngine.TAG, `QueueItEngine initialized. SDK Version: ${this.sdkVersion}`);
    }

    public get sdkVersion(): string {
        return VersionManager.getSdkVersion();
    }

    // --- Public API Methods ---

    public async run(): Promise<void> {
        Logger.debug(QueueItEngine.TAG, "run() called");
        await this.runWithConnection(undefined, undefined);
    }

    public async runWithEnqueueToken(enqueueToken: string): Promise<void> {
        Logger.debug(QueueItEngine.TAG, "runWithEnqueueToken() called");
        if (!enqueueToken) {
            Logger.error(QueueItEngine.TAG, "EnqueueToken cannot be empty");
            this.queueListener.onError(QueueError.INVALID_RESPONSE, "EnqueueToken cannot be empty");
            return;
        }
        await this.runWithConnection(enqueueToken, undefined);
    }

    public async runWithEnqueueKey(enqueueKey: string): Promise<void> {
        Logger.debug(QueueItEngine.TAG, "runWithEnqueueKey() called");
        if (!enqueueKey) {
            Logger.error(QueueItEngine.TAG, "EnqueueKey cannot be empty");
            this.queueListener.onError(QueueError.INVALID_RESPONSE, "EnqueueKey cannot be empty");
            return;
        }
        await this.runWithConnection(undefined, enqueueKey);
    }

    public async tryPass(enqueueToken?: string, enqueueKey?: string): Promise<QueueTryPassResult | null> {
        Logger.debug(QueueItEngine.TAG, `tryPass(${enqueueToken}, ${enqueueKey}) called`);
        try {
            const queueITWaitingRoomProviderResult = await this.provider.tryEnqueue(enqueueToken, enqueueKey);
            if (queueITWaitingRoomProviderResult.error) {
                this.handleError(queueITWaitingRoomProviderResult.error, queueITWaitingRoomProviderResult.errorMessage);
                return null;
            }

            return queueITWaitingRoomProviderResult.result ?? null;
        } catch (e) {
            this.handleError(QueueError.API_ERROR, e.message);
            return null;
        }
    }

    public showQueue(queueTryPassResult: QueueTryPassResult): void {
        Logger.debug(QueueItEngine.TAG, "showQueue() called");
        if (queueTryPassResult.redirectType === RedirectType.Queue && queueTryPassResult.queueUrl) {
            this.viewManager.showQueue(queueTryPassResult);
        } else {
            Logger.warn(QueueItEngine.TAG, `showQueue() called but result type is ${queueTryPassResult.redirectType}. View not shown.`);

            if (queueTryPassResult.isPassedThrough) {
                this.queueListener.onQueuePassed(new QueuePassedInfo(queueTryPassResult.queueItToken));
            } else {
                this.handlePassOrDisabled(queueTryPassResult);
            }
        }
    }

    // --- Internal Logic ---
    private async runWithConnection(enqueueToken?: string, enqueueKey?: string): Promise<void> {
        try {
            const queueITWaitingRoomProviderResult = await this.provider.tryEnqueue(enqueueToken, enqueueKey);
            Logger.debug(QueueItEngine.TAG, `checkResult: ${JSON.stringify(queueITWaitingRoomProviderResult)}`);
            if (queueITWaitingRoomProviderResult.error) {
                this.handleError(queueITWaitingRoomProviderResult.error, queueITWaitingRoomProviderResult.errorMessage);
                return;
            }

            if (!queueITWaitingRoomProviderResult.result) {
                this.handleError(QueueError.INVALID_RESPONSE, "Check result was unexpectedly null");
                return;
            }

            const resultData = queueITWaitingRoomProviderResult.result;
            Logger.debug(QueueItEngine.TAG, `resultData: ${JSON.stringify(resultData)}`);
            if (queueITWaitingRoomProviderResult.shouldEnqueue) {
                Logger.info(QueueItEngine.TAG, "Enqueue required. Showing queue view.");
                this.viewManager.showQueue(resultData);
            } else {
                this.handlePassOrDisabled(resultData);
            }
        } catch (error) {
            this.handleError(error.queueError || QueueError.API_ERROR, error.message);
        }
    }

    private handlePassOrDisabled(result: QueueTryPassResult): void {
        switch (result.redirectType) {
            case RedirectType.SafetyNet:
            case RedirectType.DirectLink:
                Logger.info(QueueItEngine.TAG, `Queue Passed (Type: ${result.redirectType}). Token: ${result.queueItToken}`);
                this.queueListener.onQueuePassed(new QueuePassedInfo(result.queueItToken));
                break;
            case RedirectType.Disabled:
            case RedirectType.AfterEvent:
            case RedirectType.Idle:
                 Logger.info(QueueItEngine.TAG, `Queue Disabled (Type: ${result.redirectType}). Token: ${result.queueItToken}`);
                this.queueListener.onQueueDisabled(new QueueDisabledInfo(result.queueItToken));
                break;
            case RedirectType.Queue:
                Logger.error(QueueItEngine.TAG, "Inconsistent state: ShouldEnqueue was false but RedirectType is Queue.");
                this.queueListener.onError(QueueError.INVALID_RESPONSE, "Inconsistent state during check");
                break;
            case RedirectType.Unknown:
            default:
                Logger.error(QueueItEngine.TAG, `Unhandled redirect type: ${result.redirectType}`);
                this.queueListener.onError(QueueError.INVALID_RESPONSE, `Unhandled redirect type: ${result.redirectType}`);
                break;
        }
    }

    private handleError(error: QueueError, message?: string): void {
        const errorMessage = message || "An unknown error occurred";
        Logger.error(QueueItEngine.TAG, `Check failed: ${error} - ${errorMessage}`);
        switch (error) {
            case QueueError.NO_CONNECTION:
                this.queueListener.onError(error, errorMessage);
                break;
            case QueueError.QUEUEIT_UNAVAILABLE:
                this.queueListener.onQueueItUnavailable();
                break;
            case QueueError.REQUEST_IN_PROGRESS:
                Logger.warn(QueueItEngine.TAG, "Attempted action while request was in progress.");
                break;
            case QueueError.INVALID_RESPONSE:
            case QueueError.SSL_ERROR:
            case QueueError.API_ERROR:
            case QueueError.AAID_ERROR:
            default:
                this.queueListener.onError(error, errorMessage);
                break;
        }
    }

    public getWebViewManager(): QueueItViewManager {
        return this.viewManager;
    }
}
