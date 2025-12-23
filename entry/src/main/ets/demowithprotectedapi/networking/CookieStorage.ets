// src/main/ets/networking/CookieStorage.ts
import { Logger } from 'queueit-library';

export class CookieStorage {
    private static readonly TAG = "CookieStorage";
    private cookies: Set<string> = new Set();

    public store(newCookies: string[] | Set<string>): void {
        this.cookies = new Set(newCookies);
        Logger.debug(CookieStorage.TAG, `Stored ${this.cookies.size} cookies.`);
    }

    public getCookies(): Set<string> {
        return this.cookies;
    }

    public clear(): void {
        this.cookies.clear();
        Logger.debug(CookieStorage.TAG, "Cookies cleared.");
    }
}