import {
  QueueItEngine, QueueListener, QueuePassedInfo, QueueDisabledInfo, QueueError,
  QueueITViewManager, QueueITApiClient, QueueView
} from 'queueit-library';

import { ProductRepository, Product } from '../demowithprotectedapi/networking/ProductRepository';
import { MustBeQueuedError } from '../demowithprotectedapi/exceptions/MustBeQueuedError';

import promptAction from '@ohos.promptAction';
import common from '@ohos.app.ability.common';
import url from '@ohos.url';
import { Context } from '@kit.AbilityKit';

@Builder
export function DemoWithProtectedAPIPageBuilder() {
    DemoWithProtectedAPIPage();
}

@Component
export struct DemoWithProtectedAPIPage {
    private productRepository: ProductRepository = new ProductRepository("https://fastly.v3.ticketania.com");
    @State isFetchingProduct: boolean = false;
    @State productInfo: string = '';
    @State productFetchError: string = '';
    @State queueViewManager: QueueITViewManager | null = null;
    @State navPathStack: NavPathStack = new NavPathStack();
    @State isTestEnvironment: boolean = true;

    async fetchProduct() {
        this.isFetchingProduct = true;
        this.productInfo = '';
        this.productFetchError = '';

        try {
            promptAction.showToast({ message: "Fetching product..." });
            const product = await this.productRepository.getProduct();
            this.productInfo = `Success! Fetched product: ${product.name}`;
            promptAction.showToast({ message: this.productInfo });
        } catch (e) {
            if (e instanceof MustBeQueuedError) {
                this.productFetchError = "Redirected to queue. Please wait.";
                promptAction.showToast({ message: "You must be queued." });
                // Now, trigger the queueing logic
                this.handleQueueRedirect(e.redirectUrl);
            } else {
                // Handle other errors (network, etc.)
                this.productFetchError = `Error fetching product: ${e.message}`;
                promptAction.showToast({ message: this.productFetchError });
            }
        } finally {
            this.isFetchingProduct = false;
        }
    }

    // --- QueueListener Implementation ---
    private createQueueListener(): QueueListener {
        return {
            onQueuePassed: (info: QueuePassedInfo) => {
                this.queueViewManager?.hideQueue();
                promptAction.showToast({ message: "Passed queue! Retrying product fetch..." });
                // Add the new token to the repository
                this.productRepository.addQueueToken(info.queueItToken);
                // Now, automatically retry the fetch
                this.fetchProduct();
            },
            onQueueViewWillOpen: () => {
                promptAction.showToast({ message: 'Queue view will open' });
            },
            onQueueDisabled: (info: QueueDisabledInfo) => {
                this.queueViewManager?.hideQueue();
                promptAction.showToast({ message: "Queue is disabled. Retrying..." });
                this.productRepository.addQueueToken(info.queueItToken);
                this.fetchProduct();
            },
            onQueueItUnavailable: () => {
                this.queueViewManager?.hideQueue();
                this.productFetchError = "Queue was unavailable during redirect.";
            },
            onError: (error: QueueError, errorMessage: string) => {
                this.queueViewManager?.hideQueue();
                this.productFetchError = `Queue error: ${errorMessage}`;
            },
            onWebViewClosed: () => {
                promptAction.showToast({ message: "Queue was cancelled." });
            },
        };
    }

    // --- End QueueListener ---

    private handleQueueRedirect(redirectUrl: string) {
        try {
            let decodedComponent = decodeURIComponent(redirectUrl);
            const parsedUrl = url.URL.parseURL(decodedComponent);
            const customerId: string | null = parsedUrl.params.get('c');
            const eventId: string | null = parsedUrl.params.get('e');
            const listener = this.createQueueListener();

            if (!customerId || !eventId) {
                this.productFetchError = "Could not parse customer/event ID from redirect URL.";
                return;
            }

            QueueITApiClient.isTest = this.isTestEnvironment;

            const context = this.getUIContext()?.getHostContext() as common.Context;

            // Create a temporary engine instance just for this queuing flow
            const redirectEngine = new QueueItEngine(context,
                customerId,
                eventId,
                listener,
                this.navPathStack);

            // IMPORTANT: Get the view manager from this new engine and assign it to the UI
            this.queueViewManager = redirectEngine.getWebViewManager();
            redirectEngine.run();
        } catch (e) {
            this.productFetchError = `Error handling queue redirect: ${e.message}`;
        }
    }

    build() {
        NavDestination() {
            Navigation(this.navPathStack) {
                Column({ space: 20 }) {
                    Text("Open Demo with protected API")
                        .fontSize(30)
                        .fontWeight(FontWeight.Bold)
                        .margin({ top: 30, bottom: 20 })

                    Button('Fetch Protected Product')
                        .onClick(() => {
                            this.fetchProduct()
                        })
                        .margin({ top: 30 })
                        .width('80%')

                    if (this.isFetchingProduct) {
                        Row() {
                            LoadingProgress().width(20).height(20).margin({ right: 5 });
                            Text("Fetching...")
                        }.margin(5)
                    } else if (this.productInfo) {
                        Text(this.productInfo).fontColor(Color.Green).margin(5)
                    } else if (this.productFetchError) {
                        Text(this.productFetchError).fontColor(Color.Red).margin(5)
                    }

                }
                .width('100%')
                .height('100%')
                .justifyContent(FlexAlign.Center)
            }
            .navDestination(this.queueItMap)
            .mode(NavigationMode.Auto)
        }
        .hideTitleBar(true) //hide parent rootPathStack
    }

    @Builder
    queueItMap(name: string) {
        if (name === 'QueueView') {
            QueueView({ viewManager: $queueViewManager })
        }
    }
}