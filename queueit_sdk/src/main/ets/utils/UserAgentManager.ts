// src/main/ets/utils/UserAgentManager.ts
import { deviceInfo } from '@kit.BasicServicesKit';
import { Logger } from './Logger';
import bundleManager from '@ohos.bundle.bundleManager';
import { VersionManager } from './VersionManager';

export class UserAgentManager {
    private static readonly TAG = "UserAgentManager";

    public static getUserAgent(defaultUA: string | null): string {
        try {
            const bundleInfo = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
            const name = bundleInfo.name;
            const versionName = bundleInfo.versionName;

            const osFullName = deviceInfo.osFullName ?? '';
            const productModel = deviceInfo.productModel ?? '';
            const brand = deviceInfo.brand;

            const sdkInfo = `(sdk: ${VersionManager.getSdkVersion()})`;
            let ua = `${name}/${versionName} ${osFullName}; ${productModel}; ${brand} ${sdkInfo}`;
            if (defaultUA != null) {
                ua = `${defaultUA} ${sdkInfo}`;
            }
            Logger.debug(UserAgentManager.TAG, `Constructed User Agent: ${ua}`);
            return ua;
        } catch (error) {
            Logger.error(UserAgentManager.TAG, `Error constructing User Agent: ${error.message}`);
            return defaultUA;
        }
    }
}