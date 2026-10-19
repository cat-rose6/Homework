import os
import time
import numpy as np
import matplotlib.pyplot as plt
import torch
import torch.nn as nn
import torch.nn.functional as F
import torch.optim as optim
from torch.utils.data import DataLoader
import torchvision
import torchvision.transforms as transforms

# 1. Deterministic Seeding and Device Setup[cite: 7]
torch.manual_seed(42)[cite: 7]
np.random.seed(42)[cite: 7]
device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')[cite: 7]

# 2. MNIST Data Pipeline[cite: 7]
transform = transforms.Compose([
    transforms.ToTensor(),
    transforms.Normalize((0.1307,), (0.3081,))
])[cite: 7]

batch_size = 64[cite: 7]
train_dataset = torchvision.datasets.MNIST(root='./data', train=True, download=True, transform=transform)[cite: 7]
test_dataset = torchvision.datasets.MNIST(root='./data', train=False, download=True, transform=transform)[cite: 7]

train_loader = DataLoader(train_dataset, batch_size=batch_size, shuffle=True, num_workers=2)[cite: 7, 8]
test_loader = DataLoader(test_dataset, batch_size=batch_size, shuffle=False, num_workers=2)[cite: 8]

# 3. Model Definition: 3-Linear-Layer Multi-Layer Perceptron[cite: 8]
class ThreeLinearLayerNet(nn.Module):[cite: 8]
    def __init__(self, in_features=784, h1=256, h2=128, out_features=10):[cite: 8]
        super(ThreeLinearLayerNet, self).__init__()[cite: 8]
        self.fc1 = nn.Linear(in_features, h1)[cite: 8]
        self.fc2 = nn.Linear(h1, h2)[cite: 8]
        self.fc3 = nn.Linear(h2, out_features)[cite: 8]

        # Kaiming (He) normal initialization[cite: 8]
        nn.init.kaiming_normal_(self.fc1.weight, mode='fan_in', nonlinearity='relu')[cite: 8]
        nn.init.zeros_(self.fc1.bias)[cite: 8]
        nn.init.kaiming_normal_(self.fc2.weight, mode='fan_in', nonlinearity='relu')[cite: 8]
        nn.init.zeros_(self.fc2.bias)[cite: 8]
        nn.init.xavier_normal_(self.fc3.weight)[cite: 8]
        nn.init.zeros_(self.fc3.bias)[cite: 8]

    def forward(self, x):[cite: 8]
        x = x.view(x.size(0), -1)  # Flatten (B, 1, 28, 28) -> (B, 784)[cite: 8]
        x = F.relu(self.fc1(x))[cite: 8]
        x = F.relu(self.fc2(x))[cite: 8]
        x = self.fc3(x)[cite: 8]
        return x[cite: 8]

net = ThreeLinearLayerNet().to(device)[cite: 8]

# 4. Objective Function & Optimizer[cite: 8]
criterion = nn.CrossEntropyLoss()[cite: 8]
optimizer = optim.SGD(net.parameters(), lr=0.01, momentum=0.9)[cite: 8]

# 5. Accuracy Evaluation Function[cite: 8]
def evaluate_accuracy(loader, model):[cite: 8]
    model.eval()[cite: 8]
    correct, total = 0, 0[cite: 8]
    with torch.no_grad():[cite: 8]
        for images, labels in loader:[cite: 8]
            images, labels = images.to(device), labels.to(device)[cite: 8]
            outputs = model(images)[cite: 8]
            preds = outputs.argmax(dim=1)[cite: 8]
            total += labels.size(0)[cite: 8]
            correct += (preds == labels).sum().item()[cite: 8]
    return 100.0 * correct / total[cite: 8]

# 6. Training Loop (10 Epochs)[cite: 8]
epochs = 10[cite: 8]
train_acc_history, test_acc_history = [], [][cite: 8]

for epoch in range(epochs):[cite: 8]
    net.train()[cite: 8]
    running_loss = 0.0[cite: 8]
    for inputs, labels in train_loader:[cite: 8]
        inputs, labels = inputs.to(device), labels.to(device)[cite: 8]
        optimizer.zero_grad()[cite: 8]
        outputs = net(inputs)[cite: 8]
        loss = criterion(outputs, labels)[cite: 8]
        loss.backward()[cite: 8]
        optimizer.step()[cite: 8]
        running_loss += loss.item() * inputs.size(0)[cite: 8]

    train_acc = evaluate_accuracy(train_loader, net)[cite: 8]
    test_acc = evaluate_accuracy(test_loader, net)[cite: 8]
    train_acc_history.append(train_acc)[cite: 8]
    test_acc_history.append(test_acc)[cite: 8]
    print(f"Epoch [{epoch+1:2d}/{epochs:2d}] | Train Acc: {train_acc:.2f}% | Test Acc: {test_acc:.2f}%")[cite: 8]

# 7. Generate and Save Single Accuracy Graph as JPG[cite: 8]
plt.figure(figsize=(9, 5.5), dpi=300)[cite: 8]
epochs_range = np.arange(1, epochs + 1)[cite: 8]
plt.plot(epochs_range, train_acc_history, 'o-', color='#1f77b4', linewidth=2.2, label='Training Accuracy')[cite: 8]
plt.plot(epochs_range, test_acc_history, 's--', color='#d62728', linewidth=2.2, label='Test Accuracy (Generalization)')[cite: 8]
plt.title('Three-Linear-Layer NN on MNIST: Accuracy Trajectory', fontsize=13, fontweight='bold')[cite: 8]
plt.xlabel('Epoch', fontsize=11, fontweight='bold')[cite: 8]
plt.ylabel('Classification Accuracy (%)', fontsize=11, fontweight='bold')[cite: 8]
plt.xticks(epochs_range)[cite: 8]
plt.grid(True, linestyle='--', alpha=0.6)[cite: 8]
plt.legend(loc='lower right')[cite: 8]
plt.tight_layout()[cite: 8]
plt.savefig('accuracy_trajectory.jpg', format='jpg', dpi=300)[cite: 8]