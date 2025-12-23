// src/main/ets/utils/Logger.ts
import hilog from '@ohos.hilog';

const DOMAIN = 0x0001;
const PREFIX = "[QueueItSDK]";


export class Logger {

    private static logLevel: hilog.LogLevel = hilog.LogLevel.ERROR;

    static debug(tag: string, message: string, ...args: any[]): void {
        if (this.logLevel <= hilog.LogLevel.DEBUG) {
            hilog.debug(DOMAIN, `${PREFIX}${tag}`, message, args);
        }
    }

    static info(tag: string, message: string, ...args: any[]): void {
        if (this.logLevel <= hilog.LogLevel.INFO) {
            hilog.info(DOMAIN, `${PREFIX}${tag}`, message, args);
        }
    }

    static warn(tag: string, message: string, ...args: any[]): void {
        if (this.logLevel <= hilog.LogLevel.WARN) {
            hilog.warn(DOMAIN, `${PREFIX}${tag}`, message, args);
        }
    }

    static error(tag: string, message: string, ...args: any[]): void {
        if (this.logLevel <= hilog.LogLevel.ERROR) {
            hilog.error(DOMAIN, `${PREFIX}${tag}`, message, args);
        }
    }

    static fatal(tag: string, message: string, ...args: any[]): void {
        hilog.fatal(DOMAIN, `${PREFIX}${tag}`, message, args);
    }

    static setLogLevel(level: hilog.LogLevel): void {
        Logger.logLevel = level;
    }
}