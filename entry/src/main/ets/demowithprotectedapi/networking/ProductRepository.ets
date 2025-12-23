// src/main/ets/networking/ProductRepository.ts
import { http } from '@kit.NetworkKit';
import { CookieStorage } from './CookieStorage';
import { MustBeQueuedError } from '../exceptions/MustBeQueuedError';
import { url } from '@kit.ArkTS';

import {
    Logger, UserAgentManager
} from 'queueit-library';

// Define the API response structure for the product
export interface Product {
    name: string;
}

export class ProductRepository {
    private static readonly TAG = "ProductRepository";
    private queueItToken: string | null = null;
    private cookieStorage: CookieStorage = new CookieStorage();
    private baseUrl: string;

    constructor(baseUrl: string) {
        this.baseUrl = baseUrl;
    }

    public addQueueToken(token: string | null): void {
        this.queueItToken = token;
        Logger.debug(ProductRepository.TAG, `Queue-it token set.`);
    }

    public async getProduct(): Promise<Product> {
        const httpRequest = http.createHttp();

        // 1. **Prepare the request URL (Logic from QueueITInterceptor)**
        let finalUrl = url.URL.parseURL(this.baseUrl + "/safeaction?queue-event1-nodomain=t");
        if (this.queueItToken) {
            finalUrl.params.append('queueittoken', this.queueItToken);
        }
        const urlString = finalUrl.toString();

        // 2. **Prepare the request headers (Logic from various interceptors)**
        const headers: Record<string, string | number | string[]> = {
            'Content-Type': 'application/json',
            'User-Agent': UserAgentManager.getUserAgent(null),
            'x-queueit-ajaxpageurl': urlString
        };

        // Add stored cookies (Logic from AddCookiesInterceptor)
        const storedCookies = this.cookieStorage.getCookies();
        if (storedCookies.size > 0) {
            headers['Cookie'] = Array.from(storedCookies).join('; ');
        }

        Logger.debug(ProductRepository.TAG, `Fetching product from: ${urlString}`);

        try {
            // 3. **Make the API call**
            const response = await httpRequest.request(urlString, {
                method: http.RequestMethod.GET,
                header: headers
            });

            Logger.debug(ProductRepository.TAG, `Response Code: ${response.responseCode}`);

            // 4. **Process the response (Logic from Interceptors)**

            // Handle cookies from response (Logic from ReceivedCookiesInterceptor)
            const setCookieHeader: Record<string, string | number | string[]> =
                Reflect.get(response.header, 'Set-Cookie');

            let receivedCookies: string[] = [];

            if (Array.isArray(setCookieHeader)) {
                receivedCookies = setCookieHeader as string[];
            } else if (typeof setCookieHeader === 'string') {
                receivedCookies = [setCookieHeader];
            }

            if (receivedCookies.length > 0) {
                this.cookieStorage.store(receivedCookies);
            }

            // Check for queue redirect (Logic from QueueITInterceptor)
            if (response.header['x-queueit-redirect']) {
                const redirectUrl = response.header['x-queueit-redirect'] as string;
                Logger.warn(ProductRepository.TAG, `Queue redirect triggered. URL: ${redirectUrl}`);
                // Clear token and cookies before throwing
                this.addQueueToken(null);
                this.cookieStorage.clear();
                throw new MustBeQueuedError(redirectUrl);
            }

            if (response.responseCode < 200 || response.responseCode >= 300) {
                throw new Error(`HTTP Error ${response.responseCode}: ${response.result}`);
            }

            // 5. **Return successful result**
            if (typeof response.result === 'string') {
                return JSON.parse(response.result) as Product;
            } else {
                throw new Error("Invalid response format from server.");
            }
        } finally {
            httpRequest.destroy();
        }
    }
}