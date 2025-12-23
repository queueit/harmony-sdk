// src/main/ets/utils/UserIdManager.ts
import { Logger } from './Logger';
import { AAID } from '@kit.PushKit';

export class UserIdManager {
    private static readonly TAG = "UserIdManager";

    public static async getUserId(): Promise<string | null> {
        try {
            const aaid = await AAID.getAAID();
            return aaid;
        } catch (err) {
            Logger.error(UserIdManager.TAG, `Failed to get AAID: ${JSON.stringify(err)}`);
            return null;
        }
    }
}
