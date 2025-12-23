export class VersionManager {
    private static readonly SDK_VERSION: string = "Harmony-1.0.0";

    public static getSdkVersion(): string {
        return this.SDK_VERSION;
    }
}