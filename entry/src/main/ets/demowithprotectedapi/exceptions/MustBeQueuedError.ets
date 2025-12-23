// src/main/ets/exceptions/MustBeQueuedError.ts

/**
 * Thrown when an API call to a protected endpoint returns a redirect-to-queue response.
 */
export class MustBeQueuedError extends Error {
    /**
     * @param redirectUrl The full URL from the 'x-queueit-redirect' header that the user should be redirected to.
     */
    public redirectUrl: string;

    constructor(redirectUrl: string) {
        super(`Must be queued. Redirect to: ${redirectUrl}`);
        this.redirectUrl = redirectUrl;
        this.name = 'MustBeQueuedError';
    }
}