import torch
import torch.nn as nn
import torch.nn.functional as F
import torch.optim as optim
from torchvision import datasets, transforms
from torch.utils.data import DataLoader

#Load MNIST dataset
tf = transforms.ToTensor()
train = datasets.MNIST(
    root="./data",
    train=True,
    download=True,
    transform=tf
)

test = datasets.MNIST(
    root="./data",
    train=False,
    download=True,
    transform=tf
)

train_loader = DataLoader(
    train,
    batch_size=64,
    shuffle=True
)

test_loader = DataLoader(
    test,
    batch_size=64,
    shuffle=False
)

#Define the network
class Net(nn.Module):
    def __init__(self):
        super().__init__()
        self.layer1 = nn.Linear(784,196)
        self.layer2 = nn.Linear(196,49)
        self.layer3 = nn.Linear(49,10)

    def forward(self, x):
        x = x.view(x.size(0), 784)
        x = F.relu(self.layer1(x))
        x = F.relu(self.layer2(x))
        x = self.layer3(x)

        return x

model = Net()

#Loss and optimizer
layer_loss = nn.CrossEntropyLoss()
opt = optim.SGD(
    model.parameters(),
    lr=0.01,
    momentum=0.9
)

#Train
model.train()
for epoch in range(10):
    total_loss = 0.0
    for x, y in train_loader:
        opt.zero_grad()
        out = model(x)
        loss = layer_loss(out, y)
        loss.backward()
        opt.step()
        total_loss += loss.item()

    avg_loss = total_loss / len(train_loader)
    print("Epoch:", epoch + 1,
          "Loss:", round(avg_loss, 3))

print("Training is finished")

#Test accuracy
model.eval()
correct = 0
total = 0

with torch.no_grad():
    for x, y in test_loader:
        out = model(x)
        _, pred = torch.max(out, 1)
        total += y.size(0)
        correct += (pred == y).sum().item()

acc = 100* correct / total
print("Test Accuracy:",round(acc, 2), "%")