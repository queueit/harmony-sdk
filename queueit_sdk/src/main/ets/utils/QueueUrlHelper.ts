// src/main/ets/utils/QueueUrlHelper.ts
import { Logger } from './Logger';

export abstract class QueueUrlHelper {
    private static readonly TAG = "QueueUrlHelper";

    public static getParameter(queryString: string, key: string): string | null {
        if (!queryString) return null;
        const keyLower = key.toLowerCase();
        const params = queryString.split('&');
        for (const param of params) {
            const parts = param.split('=');
            if (parts.length === 2 && parts[0].toLowerCase() === keyLower) {
                try {
                    return decodeURIComponent(parts[1].replace(/\+/g, ' '));
                } catch (e) {
                    Logger.error(QueueUrlHelper.TAG, 'Decoding failed when trying to get parameter');
                    return parts[1];
                }
            }
        }
        return null;
    }

    public static urlUpdateNeeded(queueUrlStr: string | null, userId: string | null): boolean {
        if (!queueUrlStr || !userId) return false;

        const queryIndex = queueUrlStr.indexOf('?');
        if (queryIndex === -1) return true;

        const queryString = queueUrlStr.substring(queryIndex + 1);
        const currentUserId = this.getParameter(queryString, 'userId');

        return !currentUserId || currentUserId !== userId;
    }

    public static updateUrl(queueUrlStr: string | null, userId: string): string {
        if (!queueUrlStr) return "";

        const queryIndex = queueUrlStr.indexOf('?');

        const baseUrl = queryIndex === -1 ? queueUrlStr : queueUrlStr.substring(0, queryIndex);

        let originalQuery = queryIndex === -1 ? '' : queueUrlStr.substring(queryIndex + 1);

        const newParams = originalQuery.split('&').filter(param => {
            if (!param) return false;
            return param.split('=')[0].toLowerCase() !== 'userid';
        });

        newParams.push(`userId=${encodeURIComponent(userId)}`);

        return `${baseUrl}?${newParams.join('&')}`;
    }
}