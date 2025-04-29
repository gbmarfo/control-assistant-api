from abc import ABC, abstractmethod

class Tool(ABC):
    """
    Base class for all tools. Each tool should inherit from this class and implement the use method.
    """
    def __init__(self, name: str, description: str):
        self._name = name.lower()
        self._description = description

    @property
    def name(self) -> str:
        return self._name
    
    @property
    def description(self) -> str:
        return self._description

    @abstractmethod
    def use(self, query: str) -> dict:
        pass

