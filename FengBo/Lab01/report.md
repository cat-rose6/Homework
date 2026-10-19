# Three-Layer Neural Network on MNIST

## 1. Objective

The objectives of this assignment are:

1. Derive the backpropagation equation for the weight matrix \(W_3\).
2. Train a three-linear-layer neural network on the MNIST dataset and report its classification accuracy.

## 2. Backpropagation for \(W_3\)

For the third linear layer,

```math
z_3 = W_3 h_2 + b_3
```

where \(h_2\) is the output of the previous layer.

Using the chain rule,

```math
\frac{\partial L}{\partial W_3}
=
\frac{\partial L}{\partial z_3}
\frac{\partial z_3}{\partial W_3}
```

Since

```math
\frac{\partial z_3}{\partial W_3} = h_2^T
```

we obtain

```math
\boxed{
\frac{\partial L}{\partial W_3}
=
\frac{\partial L}{\partial z_3} h_2^T
}
```


## 3. Neural Network

The MNIST dataset contains handwritten digit images with 10 classes, from 0 to 9.

Each image is flattened into a 784-dimensional vector as I designed.

The neural network structure is:

```text
784 -> 196 -> 49 -> 10
```

The three linear layers are:

```python
self.layer1 = nn.Linear(784, 196)
self.layer2 = nn.Linear(196, 49)
self.layer3 = nn.Linear(49, 10)
```

ReLU activation is applied after the first and second linear layers.

## 4. Training Settings

| Parameter | Value |
|---|---|
| Dataset | MNIST |
| Loss Function | CrossEntropyLoss |
| Optimizer | SGD |
| Learning Rate | 0.01 |
| Momentum | 0.9 |
| Batch Size | 64 |
| Epochs | 10 |

## 5. Training Result

The training loss decreased continuously:

```text
Epoch: 1  Loss: 0.537
Epoch: 2  Loss: 0.192
Epoch: 3  Loss: 0.129
Epoch: 4  Loss: 0.098
Epoch: 5  Loss: 0.077
Epoch: 6  Loss: 0.064
Epoch: 7  Loss: 0.055
Epoch: 8  Loss: 0.045
Epoch: 9  Loss: 0.037
Epoch: 10 Loss: 0.032
```

Final test accuracy:

```text
Test Accuracy: 97.86%
```

Therefore,

```math
\boxed{\text{Test Accuracy} = 97.86\%}
```

## 6. Conclusion

A three-linear-layer neural network was successfully trained on the MNIST dataset.

The training loss decreased from **0.537** to **0.032**, and the final test accuracy reached **97.86%**.

The experiment also demonstrates how the gradient of \(W_3\) is obtained through backpropagation and how PyTorch automatically performs this calculation using `loss.backward()`.
