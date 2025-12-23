// src/main/ets/utils/UriOverrider.ts
import { Logger } from './Logger';
import { QueueUrlHelper } from './QueueUrlHelper';

export enum UriOverrideResult {
    LOAD_IN_WEBVIEW,
    PASSED,
    CLOSE,
    RESTART_SESSION,
    OPEN_EXTERNAL,
    BLOCK,
    DEFAULT
}

export interface UriOverrideResponse {
    action: UriOverrideResult;
    modifiedUrl?: string;
    queueItToken?: string | null;
}

interface ParsedUrl {
    scheme: string;
    host: string;
    path: string;
    query: string;
}

export class UriOverrider {
    private static readonly TAG = "UriOverrider";
    private queueHost: string | null = null;
    private targetHost: string | null = null;
    private targetPath: string | null = null;
    private userId: string | null = null;

    private parseUrlManually(urlString: string): ParsedUrl | null {
        if (!urlString) return null;
        try {
            const schemeEndIndex = urlString.indexOf('://');
            if (schemeEndIndex === -1) return null;
            const scheme = urlString.substring(0, schemeEndIndex).toLowerCase();

            let rest = urlString.substring(schemeEndIndex + 3);
            const queryStartIndex = rest.indexOf('?');

            let pathAndHost = queryStartIndex !== -1 ? rest.substring(0, queryStartIndex) : rest;
            const query = queryStartIndex !== -1 ? rest.substring(queryStartIndex + 1) : '';

            const pathStartIndex = pathAndHost.indexOf('/');
            let host = pathStartIndex !== -1 ? pathAndHost.substring(0, pathStartIndex) : pathAndHost;
            let path = pathStartIndex !== -1 ? pathAndHost.substring(pathStartIndex) : '/';

            return { scheme, host: host.toLowerCase(), path, query };
        } catch (e) {
            Logger.error(UriOverrider.TAG, `Manual URL parse failed for: ${urlString} - ${e.message}`);
            return null;
        }
    }

    public setQueueHostUrl(queueUrlStr: string | null): void {
        const parsed = this.parseUrlManually(queueUrlStr || '');
        this.queueHost = parsed ? parsed.host : null;
        Logger.debug(UriOverrider.TAG, `Queue host set to: ${this.queueHost}`);
    }

    public setTargetUrl(targetUrlStr: string | null): void {
        const parsed = this.parseUrlManually(targetUrlStr || '');
        this.targetHost = parsed ? parsed.host : null;
        this.targetPath = parsed ? parsed.path : '/';
        Logger.debug(UriOverrider.TAG, `Target host set to: ${this.targetHost}, Path set to: ${this.targetPath}`);
    }

    public setUserId(userId: string | null | undefined): void {
        this.userId = userId || null;
    }

    handleNavigationRequest(destinationUrlStr: string): UriOverrideResponse {
        Logger.debug(UriOverrider.TAG, `Intercepting: ${destinationUrlStr}`);

        if (destinationUrlStr.startsWith('queueit:')) {
            let commandPart = destinationUrlStr.substring(8);

            if (commandPart.startsWith('//')) {
                commandPart = commandPart.substring(2);
            }

            const action = commandPart.split('?')[0];

            if (action === 'close') {
                return { action: UriOverrideResult.CLOSE };
            }
            if (action === 'restartSession') {
                return { action: UriOverrideResult.RESTART_SESSION };
            }

            Logger.warn(UriOverrider.TAG, `Unknown queueit action: ${action}. Blocking.`);
            return { action: UriOverrideResult.BLOCK };
        }

        const parsedUrl = this.parseUrlManually(destinationUrlStr);

        if (!parsedUrl) {
            Logger.warn(UriOverrider.TAG, `Could not parse URL: ${destinationUrlStr}. Treating as external.`);
            return { action: UriOverrideResult.OPEN_EXTERNAL };
        }

        const { scheme, host, path, query } = parsedUrl;

        if (scheme === 'http' || scheme === 'https') {
            if (path.startsWith('/what-is-this.html')) {
                return { action: UriOverrideResult.BLOCK };
            }

            const isQueueItDomain = this.queueHost && host === this.queueHost;
            if (isQueueItDomain) {
                if (this.userId && QueueUrlHelper.urlUpdateNeeded(destinationUrlStr, this.userId)) {
                    const rewrittenUrl = QueueUrlHelper.updateUrl(destinationUrlStr, this.userId);
                    return { action: UriOverrideResult.LOAD_IN_WEBVIEW, modifiedUrl: rewrittenUrl };
                }
                return { action: UriOverrideResult.DEFAULT };
            }

            const isTargetDomain = this.targetHost && host === this.targetHost;
            const isTargetPath = this.targetPath && path === this.targetPath;
            if (isTargetDomain && isTargetPath) {
                const queueItToken = QueueUrlHelper.getParameter(query, 'queueittoken');
                if (queueItToken) {
                    return { action: UriOverrideResult.PASSED, queueItToken };
                }
                return { action: UriOverrideResult.BLOCK };
            }

            return { action: UriOverrideResult.OPEN_EXTERNAL };
        }

        return { action: UriOverrideResult.OPEN_EXTERNAL };
    }
}