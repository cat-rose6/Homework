本次作业用的是Python3.9.25，运行pip install -r requirements.txt可以安装依赖。
运行python train_mnist.py，会自动下载MNIST数据集。训练完成后，模型权重保存在results/best_model.pt，测试结果保存在results/metrics.json。
本次提交未附带模型权重。如需复核准确率，请先完成上述训练，再运行：python train_mnist.py --evaluate。复核结果保存在results/evaluation.json。
