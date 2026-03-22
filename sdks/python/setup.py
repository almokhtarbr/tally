from setuptools import setup, find_packages

setup(
    name="tally-analytics",
    version="0.1.0",
    description="Python SDK for Tally Analytics — self-hosted product analytics",
    packages=find_packages(),
    python_requires=">=3.8",
    install_requires=[],  # Zero dependencies
    classifiers=[
        "Programming Language :: Python :: 3",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
    ],
)
