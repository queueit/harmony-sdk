// src/main/ets/utils/NetworkUtils.ts
import connection from '@ohos.net.connection';
import { Logger } from './Logger';

export class NetworkUtils {
    private static readonly TAG = "NetworkUtils";

    public static async isOnline(): Promise<boolean> {
        try {
            const isConnected = await connection.hasDefaultNet();
            if (!isConnected) {
                Logger.debug(this.TAG, "No default network connection.");
                return false;
            }

            const netHandle = await connection.getDefaultNet();
            if (!netHandle) {
                Logger.debug(this.TAG, "No default network handle obtained.");
                return false;
            }

            const capabilities = await connection.getNetCapabilities(netHandle);
            if (!capabilities) {
                Logger.debug(this.TAG, "Could not get network capabilities.");
                return false;
            }

            const hasInternetAccess = capabilities.bearerTypes?.length > 0 &&
                                      capabilities.networkCap?.includes(connection.NetCap.NET_CAPABILITY_VALIDATED);


            Logger.debug(this.TAG, `Network online check: Connected=${isConnected}, ValidatedInternet=${hasInternetAccess}`);
            return !!hasInternetAccess;

        } catch (error) {
            Logger.error(this.TAG, `Error checking network state: ${error.message}`);
            return false;
        }
    }
}