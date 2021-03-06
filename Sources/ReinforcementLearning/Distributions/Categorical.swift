// Copyright 2019, Emmanouil Antonios Platanios. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License"); you may not
// use this file except in compliance with the License. You may obtain a copy of
// the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
// WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
// License for the specific language governing permissions and limitations under
// the License.

import TensorFlow

public struct Categorical<Scalar: TensorFlowIndex>: DifferentiableDistribution, KeyPathIterable {
  /// Log-probabilities of this categorical distribution.
  public var logProbabilities: Tensor<Float>

  @inlinable
  @differentiable(wrt: logProbabilities)
  public init(logProbabilities: Tensor<Float>) {
    self.logProbabilities = logProbabilities
  }

  @inlinable
  @differentiable(wrt: probabilities)
  public init(probabilities: Tensor<Float>) {
    self.logProbabilities = log(probabilities)
  }

  @inlinable
  @differentiable(wrt: logits)
  public init(logits: Tensor<Float>) {
    self.logProbabilities = logSoftmax(logits)
  }

  @inlinable
  @differentiable(wrt: self)
  public func logProbability(of value: Tensor<Scalar>) -> Tensor<Float> {
    logProbabilities.batchGathering(
      atIndices: value.expandingShape(at: -1),
      alongAxis: 2,
      batchDimensionCount: 2
    ).squeezingShape(at: -1)
  }

  @inlinable
  @differentiable(wrt: self)
  public func entropy() -> Tensor<Float> {
    -(logProbabilities * exp(logProbabilities)).sum(squeezingAxes: -1)
  }

  @inlinable
  public func mode() -> Tensor<Scalar> {
    Tensor<Scalar>(logProbabilities.argmax(squeezingAxis: 1))
  }

  @inlinable
  public func sample() -> Tensor<Scalar> {
    let seed = Context.local.randomSeed
    let outerDimCount = self.logProbabilities.rank - 1
    let logProbabilities = self.logProbabilities.flattenedBatch(outerDimCount: outerDimCount)
    let multinomial: Tensor<Scalar> = _Raw.statelessMultinomial(
      logits: logProbabilities,
      numSamples: Tensor<Int32>(1),
      seed: Tensor([seed.graph, seed.op]))
    let flattenedSamples = multinomial.gathering(atIndices: Tensor<Int32>(0), alongAxis: 1)
    return flattenedSamples.unflattenedBatch(
      outerDims: [Int](self.logProbabilities.shape.dimensions[0..<outerDimCount]))
  }
}

extension Categorical: DifferentiableKLDivergence {
  @inlinable
  @differentiable
  public func klDivergence(to target: Categorical) -> Tensor<Float> {
    (exp(logProbabilities) * (logProbabilities - target.logProbabilities)).sum(squeezingAxes: -1)
  }
}
