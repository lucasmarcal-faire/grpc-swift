/*
 * Copyright 2019, gRPC Authors All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
import Logging
@_implementationOnly import NIOCore
@_implementationOnly import NIOHPACK
@_implementationOnly import NIOHTTP2

/// A server-streaming gRPC call. The request is sent on initialization, each response is passed to
/// the provided observer block.
///
/// Note: while this object is a `struct`, its implementation delegates to `Call`. It therefore
/// has reference semantics.
public struct ServerStreamingCall<RequestPayload, ResponsePayload>: ClientCall {
  private let call: Call<RequestPayload, ResponsePayload>
  private let responseParts: StreamingResponseParts<ResponsePayload>

  /// The options used to make the RPC.
  public var options: CallOptions {
    return self.call.options
  }

  /// The path used to make the RPC.
  public var path: String {
    return self.call.path
  }

  /// The `Channel` used to transport messages for this RPC.
  public var subchannel: EventLoopFuture<Channel> {
    return self.call.channel
  }

  /// The `EventLoop` this call is running on.
  public var eventLoop: EventLoop {
    return self.call.eventLoop
  }

  /// Cancel this RPC if it hasn't already completed.
  public func cancel(promise: EventLoopPromise<Void>?) {
    self.call.cancel(promise: promise)
  }

  // MARK: - Response Parts

  /// The initial metadata returned from the server.
  public var initialMetadata: EventLoopFuture<HPACKHeaders> {
    return self.responseParts.initialMetadata
  }

  /// The trailing metadata returned from the server.
  public var trailingMetadata: EventLoopFuture<HPACKHeaders> {
    return self.responseParts.trailingMetadata
  }

  /// The final status of the the RPC.
  public var status: EventLoopFuture<GRPCStatus> {
    return self.responseParts.status
  }

  internal init(
    call: Call<RequestPayload, ResponsePayload>,
    callback: @escaping (ResponsePayload) -> Void
  ) {
    self.call = call
    self.responseParts = StreamingResponseParts(on: call.eventLoop, callback)
  }

  internal func invoke(_ request: RequestPayload) {
    self.call.invokeUnaryRequest(
      request,
      onStart: {},
      onError: self.responseParts.handleError(_:),
      onResponsePart: self.responseParts.handle(_:)
    )
  }
}
