# LYRCoreData

**Example code for integrating [LayerKit](https://layer.com/) with Core Data.**

LYRCoreData is a sample application highlighting how to integrate LayerKit, the iOS SDK for the Layer communications platform, with Apple's Core Data object persistence technology. It presents a simple, performant pattern for hydrating a managed object model from an underlying Layer object model using the change notifications emitted by LayerKit.

For some applications it may be desirable to utilize Core Data instead of or in addition to the native Layer domain objects. Such applications include those that...

* Have an existing investment in Core Data for data modeling & persistence.
* Require advanced querying capabilities beyond those provided directly by LayerKit.

## Highlights

* Demonstrates how to cleanly and performantly import Layer objects into Core Data.
* Provides a reference implementation for driving Conversation and Message UI's via an `NSFetchedResultsController`

## Configuration

In order to populate the sample app with content, you must configure the following environment variables:

* `LAYER_APP_ID`: The Layer application identifier for you application.
* `LAYER_USER_ID`: The user identifier to authenticate as.

The authentication process requires that you provide a sandbox app identifier that has been configured to use the Layer Identity Provider.

## Credits

LYRCoreData was lovingly crafted in San Francisco by Blake Watters during his work on [Layer](http://layer.com). At Layer, we are building the Communications Layer for the Internet. We value, support, and create works of Open Source engineering excellence.

Blake Watters

- http://github.com/blakewatters
- http://twitter.com/blakewatters
- blake@layer.com

## License

LYRCoreData is available under the Apache 2 License. See the LICENSE file for more info.
