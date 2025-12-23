// src/main/ets/providers/QueueITWaitingRoomProvider.ts
import { QueueItApiClient } from '../networking/QueueItApiClient';
import { QueueTryPassResult, RedirectType } from '../data/QueueModels';
import { QueueItWaitingRoomProviderResult } from '../data/QueueItWaitingRoomProviderModels';
import { QueueError } from '../data/QueueError';
import { UserAgentManager } from '../utils/UserAgentManager';
import { Logger } from '../utils/Logger';
import { NetworkUtils } from '../utils/NetworkUtils';
import { QueueUrlHelper } from '../utils/QueueUrlHelper';
import { common } from '@kit.AbilityKit';
import { UserIdManager } from '../utils/UserIdManager';
import { VersionManager } from '../utils/VersionManager';

const INITIAL_WAIT_RETRY_SEC = 1;
const MAX_RETRY_SEC = 10;
const MAX_CONNECTION_RETRIES = 3;

export class QueueItWaitingRoomProvider {
    private static readonly TAG = "QueueITWaitingRoomProvider";
    apiClient: QueueItApiClient;
    isRequestInProgress: boolean = false;

    constructor(
        private context: common.UIAbilityContext | common.ApplicationContext | common.Context,
        // Need application context for network/device info
        private customerId: string,
        private eventOrAliasId: string,
        private layoutName?: string,
        private language?: string
    ) {
        this.context = context;
        this.customerId = customerId;
        this.eventOrAliasId = eventOrAliasId;
        this.layoutName = layoutName;
        this.language = language;
        this.apiClient = new QueueItApiClient(customerId, eventOrAliasId);
    }

    public get sdkVersion(): string {
        return VersionManager.getSdkVersion();
    }

    public IsRequestInProgress(): boolean {
        return this.isRequestInProgress;
    }

    async tryEnqueue(enqueueToken?: string, enqueueKey?: string): Promise<QueueItWaitingRoomProviderResult> {
        if (this.isRequestInProgress) {
            return {
                shouldEnqueue: false,
                error: QueueError.REQUEST_IN_PROGRESS,
                errorMessage: "Request is already in progress"
            };
        }
        this.isRequestInProgress = true;

        try {
            if (!(await this.ensureNetworkConnection())) {
                return {
                    shouldEnqueue: false,
                    error: QueueError.NO_CONNECTION,
                    errorMessage: "No internet connection"
                };
            }

            const userId = await UserIdManager.getUserId();
            if (!userId) {
                return { shouldEnqueue: false, error: QueueError.AAID_ERROR, errorMessage: "Could not retrieve AAID" };
            }

            const apiResult = await this.tryEnqueueWithRetries(userId, enqueueToken, enqueueKey);

            return this.handleAppEnqueueResponse(apiResult, userId);

        } catch (error) {
            Logger.error(QueueItWaitingRoomProvider.TAG, `Try Pass failed: ${error.message}`);
            return {
                shouldEnqueue: false,
                error: error.queueError || QueueError.API_ERROR,
                errorMessage: error.message
            };
        } finally {
            this.isRequestInProgress = false;
        }
    }

    private async ensureNetworkConnection(): Promise<boolean> {
        let attempts = 0;
        while (attempts < MAX_CONNECTION_RETRIES) {
            if (await NetworkUtils.isOnline()) {
                return true;
            }
            attempts++;
            if (attempts < MAX_CONNECTION_RETRIES) {
                Logger.debug(QueueItWaitingRoomProvider.TAG, `No connection, retrying in 1s (${attempts}/${MAX_CONNECTION_RETRIES})`);
                await new Promise(resolve => setTimeout(resolve, 1000));
            }
        }
        Logger.error(QueueItWaitingRoomProvider.TAG, "Max connection retries reached.");
        return false;
    }


    private async tryEnqueueWithRetries(userId: string, enqueueToken?: string, enqueueKey?: string): Promise<any> {
        let currentRetryDelaySec = INITIAL_WAIT_RETRY_SEC;
        let lastError: any = null;

        while (currentRetryDelaySec <= MAX_RETRY_SEC) {
            try {
                const userAgent = await UserAgentManager.getUserAgent(null);
                const result = await this.apiClient.enqueue(
                    userId,
                    userAgent,
                    this.layoutName,
                    this.language,
                    enqueueToken,
                    enqueueKey
                );
                return result;
            } catch (error) {
                lastError = error;
                if (error.message?.includes("HTTP Error 4")) {
                    Logger.error(QueueItWaitingRoomProvider.TAG, `Client error ${error.message}, not retrying.`);
                    error.queueError = QueueError.INVALID_RESPONSE;
                    throw error;
                }

                Logger.warn(QueueItWaitingRoomProvider.TAG, `Enqueue attempt failed: ${error.message}. Retrying in ${currentRetryDelaySec}s`);
                await new Promise(resolve => setTimeout(resolve, currentRetryDelaySec * 1000));
                currentRetryDelaySec *= 2;
            }
        }

        Logger.error(QueueItWaitingRoomProvider.TAG, `Enqueue failed after multiple retries. Last error: ${lastError?.message}`);
        lastError.queueError = QueueError.QUEUEIT_UNAVAILABLE;
        throw lastError;
    }


    private handleAppEnqueueResponse(apiResult: any, userId: string): QueueItWaitingRoomProviderResult {
        Logger.debug(QueueItWaitingRoomProvider.TAG, `apiResult: ${JSON.stringify(apiResult)}`);
        //need upper letter on json parse
        const queueItToken = apiResult.QueueitToken || null;
        const queueUrl = apiResult.QueueUrl || null;
        const targetUrl = apiResult.EventTargetUrl || null;
        const queueUrlTtlInMinutes = apiResult.QueueUrlTTLInMinutes || null; //need upper letter on json parse

        const isPassedThrough = queueItToken !== null && queueItToken.trim() !== '';
        const redirectType = this.getRedirectTypeFromToken(queueItToken);

        const updatedQueueUrl = queueUrl && QueueUrlHelper.urlUpdateNeeded(queueUrl, userId)
            ? QueueUrlHelper.updateUrl(queueUrl, userId)
            : queueUrl;

        const result = new QueueTryPassResult(
            queueItToken,
            updatedQueueUrl,
            targetUrl,
            isPassedThrough,
            redirectType,
            queueUrlTtlInMinutes
        );

        const shouldEnqueue = redirectType === RedirectType.Queue;
        Logger.debug(QueueItWaitingRoomProvider.TAG, `shouldEnqueue: ${shouldEnqueue}, result: ${JSON.stringify(result)}`);
        return { shouldEnqueue, result };
    }

    getRedirectTypeFromToken(queueItToken: string | null): RedirectType {
        if (!queueItToken) {
            return RedirectType.Queue;
        }
        const match = queueItToken.match(/~rt_([a-zA-Z]+)~/);
        if (match && match[1]) {
            const typeString = match[1].toLowerCase();
            switch (typeString) {
                case 'safetynet': return RedirectType.SafetyNet;
                case 'afterevent': return RedirectType.AfterEvent;
                case 'disabled': return RedirectType.Disabled;
                case 'directlink': return RedirectType.DirectLink;
                case 'idle': return RedirectType.Idle;
                case 'queue': return RedirectType.Queue;
                default:
                    Logger.warn(QueueItWaitingRoomProvider.TAG, `Unknown redirect type string: ${typeString}`);
                    return RedirectType.Unknown;
            }
        } else {
            Logger.debug(QueueItWaitingRoomProvider.TAG, `No ~rt_ marker in token, assuming Unknown: ${queueItToken}`);
            return RedirectType.Unknown;
        }
    }
}
