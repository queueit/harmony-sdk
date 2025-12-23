// src/main/ets/networking/QueueITApiClient.ts
import { http } from '@kit.NetworkKit';
import { Logger } from '../utils/Logger';
import { EnqueueRequestBody, EnqueueSuccessResponse } from '../data/QueueEnqueueModels';
import { VersionManager } from '../utils/VersionManager';

export class QueueItApiClient {
    private static readonly TAG = "QueueITApiClient";
    public static isTest: boolean = false;

    constructor(
        private customerId: string,
        private eventOrAliasId: string
    ) {
    }

    private getEnqueueApiUrl(userId: string): string {
        const hostname = `${this.customerId}.${QueueItApiClient.isTest ? 'test.' : ''}queue-it.net`;
        const path = `api/mobileapp/queue/${this.customerId}/${this.eventOrAliasId}/enqueue`;
        return `https://${hostname}/${path}?userId=${encodeURIComponent(userId)}`;
    }

    public async enqueue(
        userId: string,
        userAgent: string,
        layoutName?: string,
        language?: string,
        enqueueToken?: string,
        enqueueKey?: string
    ): Promise<EnqueueSuccessResponse> {
        const url = this.getEnqueueApiUrl(userId);
        const sdkVersion = VersionManager.getSdkVersion();

        const requestBody: EnqueueRequestBody = {
            userId,
            userAgent,
            sdkVersion,
            ...(layoutName && { layoutName }),
            ...(language && { language }),
            ...(enqueueToken && { enqueueToken }),
            ...(enqueueKey && { enqueueKey }),
        };

        const httpRequest = http.createHttp();
        try {
            Logger.debug(QueueItApiClient.TAG, `API Call: POST ${url} Body: ${JSON.stringify(requestBody)}`);
            const response = await httpRequest.request(url, {
                method: http.RequestMethod.POST,
                header: { 'Content-Type': 'application/json; charset=utf-8' },
                extraData: JSON.stringify(requestBody),
            });
            Logger.debug(QueueItApiClient.TAG, `API Response: ${response.responseCode} Body: ${response.result}`);

            if (response.responseCode < 200 || response.responseCode >= 400) {
                throw new Error(`HTTP Error ${response.responseCode}: ${response.result}`);
            }

            if (typeof response.result !== 'string') {
                throw new Error('Invalid API response type');
            }

            try {
                const data: EnqueueSuccessResponse = JSON.parse(response.result);
                return data;
            } catch (parseError) {
                Logger.error(QueueItApiClient.TAG, `JSON Parse Error: ${parseError.message} Body: ${response.result}`);
                throw new Error(`Server did not return valid JSON: ${response.result}`);
            }

        } catch (error) {
            Logger.error(QueueItApiClient.TAG, `API Request Failed: ${error.message}`);
            throw error;
        } finally {
            httpRequest.destroy();
        }
    }
}
