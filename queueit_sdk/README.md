# Queue-it HarmonyOS ArkTS/ArkUI SDK

[//]: # (Add badges here when available, e.g., for HAR version or license)

Library for integrating Queue-it's virtual waiting room into a HarmonyOS Next application built with ArkTS and ArkUI.

This SDK is for the HarmonyOS Next ecosystem (API version 12 and higher).

## Installation

Before starting, please download the "Mobile App Integration" whitepaper from the GO Queue-it Platform. This document contains essential information for a successful integration.


```bash
ohpm install queueit-library
```

## Required Permissions

Add the following permissions to your application's `src/main/module.json5` file.

```json5
// src/main/module.json5
{
  "module": {
    // ... other module properties
    "requestPermissions": [
      {
        "name": "ohos.permission.INTERNET",
        "reason": "$string:internet_permission_reason",
        "usedScene": {
          "abilities": [ ".EntryAbility" ],
          "when": "inuse"
        }
      },
      {
        "name": "ohos.permission.GET_NETWORK_INFO",
        "reason": "$string:network_permission_reason",
        "usedScene": {
          "abilities": [ ".EntryAbility" ],
          "when": "inuse"
        }
      }
    ]
  }
}
```
*Remember to define `internet_permission_reason` and `network_permission_reason` in your `src/main/resources/base/element/string.json` file.*

## How to Use the Library

As the app developer, you must manage the state (i.e., whether the user was previously queued up). After receiving the `onQueuePassed` callback, your app should store this state, potentially with a date/time expiration. When the user navigates to a protected part of the app, your code should check this state and only trigger the Queue-it logic if the user has not recently passed the queue.

### 1. UI Integration using Navigation

The SDK uses HarmonyOS's `Navigation` component to present the queue page. Your page must be set up to host a `Navigation` container and provide the SDK with its `NavPathStack`.

The integration steps are:
1.  Wrap your page content in a `Navigation` component, providing it with an `@State NavPathStack`.
2.  When initializing `QueueItEngine`, pass this `NavPathStack` instance to its constructor.
3.  Define a destination builder for the `Navigation` component that maps the route name `'QueueView'` to the SDK's `<QueueView>` component.

Here is a complete example of the UI setup:

```typescript
// In your page, e.g., DemoPage.ets

import { QueueItEngine, QueueITViewManager, QueueView } from 'queueit-library';

@Component
struct MyPage {
  // 1. Navigation state for your page
  @State navPathStack: NavPathStack = new NavPathStack();
  
  // 2. State for the SDK components
  @State engine: QueueItEngine | null = null;
  @State queueViewManager: QueueITViewManager | null = null;

  async initializeSdk() {
    // ... (code to get context, define listener, etc.)

    // 3. Pass your NavPathStack to the engine
    this.engine = new QueueItEngine(
        context,
        customerId,
        eventId,
        listener,
        this.navPathStack // Pass the stack here
    );
    this.queueViewManager = this.engine.getWebViewManager();
  }

  // 4. Define the destination builder
  @Builder queueItMap(name: string) {
    if (name === 'QueueView') {
      // The view manager must be linked with '$'
      QueueView({ viewManager: $queueViewManager })
    }
  }
  
  build() {
    NavDestination() {
      // 5. Use the Navigation component as the container
      Navigation(this.navPathStack) {
        Column() {
          // Your page content (buttons, text, etc.) goes here
          Button('Enter Event').onClick(() => this.engine.run())
        }
      }
      .navDestination(this.queueItMap) // Attach the builder
      .mode(NavigationMode.Auto)
    }
  }
}
```
When the SDK needs to show the queue, it will automatically push the `QueueView` onto your `navPathStack`.

### 2. Simple Integration using `run()`

The simplest integration requires you to call the asynchronous `run()` method. The SDK will handle the rest, including pushing the `QueueView` to the navigation stack if necessary.

```typescript
// In your page, e.g., DemoPage.ets

import {
  QueueItEngine,
  QueueListener,
  QueuePassedInfo,
  QueueDisabledInfo,
  QueueError,
  QueueITApiClient
} from 'queueit-library';
import common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';

// ... inside your @Component struct

// 1. Define the listener to handle callbacks from the SDK
private createQueueListener(): QueueListener {
  return {
    onQueuePassed: (info: QueuePassedInfo) => {
      this.isLoadingSdk = false;
      // The QueueView is hidden automatically by the manager
      // Navigate to your protected content
      this.queueViewManager?.hideQueue();
      promptAction.showToast({ message: `Queue Passed! Token: ${info.queueItToken}` });
    },
    onQueueViewWillOpen: () => {
      this.isLoadingSdk = false;
      promptAction.showToast({ message: 'Queue view will open' });
    },
    // ... other listener methods ...
    onError: (error: QueueError, errorMessage: string) => {
      this.isLoadingSdk = false;
      this.queueViewManager?.hideQueue();
      promptAction.showToast({ message: `Critical error: ${errorMessage}` });
    },
    onWebViewClosed: () => {
      this.isLoadingSdk = false;
    }
  };
}

// 2. Initialize the engine and run it
async function handleRunQueue() {
  if (!this.engine) {
    const context = getContext(this) as common.UIAbilityContext;
    const listener = this.createQueueListener();
    
    // Remember to pass the NavPathStack
    this.engine = new QueueItEngine(
        context,
        this.customerIdInput,
        this.eventIdInput,
        listener,
        this.navPathStack
    );
    this.queueViewManager = this.engine.getWebViewManager();
  }

  QueueITApiClient.isTest = this.isTestEnvironment;
  this.isLoadingSdk = true;
  
  try {
    // Await the run method. This will push the QueueView if needed.
    await this.engine.run();
  } catch (e) {
    this.isLoadingSdk = false;
    promptAction.showToast({ message: `Error running engine: ${e.message}` });
  }
}
```

`hideQueue()` is used to close the queue page webview programmatically.

### 3. Granular Integration with `tryPass()` and `showQueue()`

For more control, first check the user's status with `tryPass()` and then manually decide to show the queue page.

```typescript
// In your page, e.g., DemoPage.ets

async handleTryPass() {
  // 1. Initialize engine if needed (see run() example)
  if (!this.engine) {
     if (!await this.initializeSdkEngine()) return;
  }
  
  this.isLoadingSdk = true;
  try {
    // 2. Check the waiting room status
    const result = await this.engine.tryPass();
    this.isLoadingSdk = false;

    if (result) {
      if (result.redirectType === RedirectType.Queue) {
        // User needs to be enqueued. Store the result and enable a button
        // that the user can click to enter the queue.
        this.tryPassResultInternal = result;
        this.isShowQueueButtonEnabled = true;
      } else {
        // User has passed, or queue is disabled. Proceed to content.
      }
    }
  } catch (e) { /* ... Handle errors ... */ }
}

// 3. Call showQueue() based on the tryPass() result
handleShowQueue() {
  if (this.engine && this.tryPassResultInternal) {
    // This will push the QueueView onto the navigation stack
    this.engine.showQueue(this.tryPassResultInternal);
  }
}
```

### 4. Handling the Back Button

The SDK automatically handles back button presses when the `QueueView` is active. It will either navigate back within the WebView's history or pop itself from the navigation stack. The `disableBackButtonFromWR` option in `QueueItEngineOptions` is respected.

No additional `onBackPressed` code is required from the consuming page.

### `QueueItEngineOptions`

You can configure the engine by passing an `options` object to the constructor.

```typescript
import { QueueItEngineOptions } from 'queueit-library';

const options = new QueueItEngineOptions();
// Disables the hardware/software back button while the queue view is shown
options.disableBackButtonFromWR = true; 
// Set a custom User-Agent for the WebView
options.webViewUserAgent = "MyCustomApp/1.0.0";
// Set a delay in milliseconds before the queue view is displayed
options.viewDelayMs = 500;```

## Integration with Connector Protected APIs

If your application calls an API protected by a Queue-it connector (KnownUser), you need to handle potential redirects from the API layer.

The flow is as follows:
1.  **Make API Request**: Your app makes a standard API request.
2.  **Catch `MustBeQueuedError`**: If the user needs to be queued, your API client should throw a specific error containing the redirect URL from the `x-queueit-redirect` header.
3.  **Handle Redirect**: In your UI logic, catch this error.
4.  **Parse IDs**: Extract the Customer ID (`c`) and Event ID (`e`) from the redirect URL.
5.  **Run Queue Flow**: Instantiate a new `QueueItEngine` with the parsed IDs and your page's `NavPathStack`. Call `run()` to show the queue view to the user.
6.  **Retry API Call**: In the `onQueuePassed` callback, store the new `queueItToken` and retry the original API request. This time, your API client should include the token with the request.

```typescript
// In your UI code, e.g., DemoWithProtectedAPIPage.ets
import { MustBeQueuedError } from '../demowithprotectedapi/exceptions/MustBeQueuedError';
import url from '@ohos.url';

async function fetchProduct() {
  try {
    const product = await this.productRepository.getProduct();
    // Handle successful fetch
  } catch (e) {
    if (e instanceof MustBeQueuedError) {
      // Trigger the queueing logic
      handleQueueRedirect(e.redirectUrl);
    } else {
      // Handle other errors
    }
  }
}

function handleQueueRedirect(redirectUrl: string) {
  try {
    const parsedUrl = url.URL.parseURL(decodeURIComponent(redirectUrl));
    const customerId = parsedUrl.params.get('c');
    const eventId = parsedUrl.params.get('e');
    const listener = this.createQueueRedirectListener(); // A listener that retries the fetch on pass

    // Create a temporary engine to handle this specific redirect
    const redirectEngine = new QueueItEngine(context, customerId, eventId, listener, this.navPathStack);
    
    // Assign its manager to the UI state to make the QueueView's NavDestination work
    this.queueViewManager = redirectEngine.getWebViewManager();
    redirectEngine.run();
  } catch (e) {
    // Handle parsing errors
  }
}

// In your QueueListener for this flow:
onQueuePassed: (info: QueuePassedInfo) => {
  // The view manager hides the queue view automatically.
  promptAction.showToast({ message: "Passed queue! Retrying product fetch..." });
  
  // Add the new token to the repository for the next API call
  this.productRepository.addQueueToken(info.queueItToken);
  
  // Retry the original request
  this.fetchProduct();
}
```

## License

This SDK is licensed under the MIT License. See the `LICENSE` file for details.