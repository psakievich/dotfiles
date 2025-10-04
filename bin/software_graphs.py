from graphviz import Digraph


class GraphNode:
    def __init__(self, name, label=None, deps=[], **kwargs):
        self.name = name
        self.label = label
        self.deps = deps
        for name, value in kwargs.items():
            setattr(self, name, value)
        self.exclude_attrs = ["name", "label", "deps", "exclude_attrs"]
        self.style = "filled"

    def add_to_digraph(self, graph):
        node_attrs = {k:v for k,v in vars(self).items() if k not in self.exclude_attrs}
        graph.node(self.name, self.label, **node_attrs)


def color_nodes(nodes, change_set=[], color=None):
    colored_nodes = []
    for node in nodes:
        if node.name in change_set:
            setattr(node, "color", color)
            setattr(node, "style", "filled")
            colored_nodes.append(node)
    return colored_nodes


def ci_coloring(nodes, change_set):
    changes = color_nodes(nodes, change_set, "red")
    while changes:
        new_change_set = set([d for n in changes for d in n.deps])
        changes = color_nodes(nodes, new_change_set, "orange")


def clear_attrs(nodes):
    for node in nodes:
        attrs_to_clear = [k for k in vars(node).keys() if k not in node.exclude_attrs]
        for attr in attrs_to_clear:
            delattr(node, attr)


def assemble(nodes, graph):
    for i, node in enumerate(nodes):
        node.add_to_digraph(graph)

    for node in nodes:
        for dep in node.deps:
            graph.edge(node.name, dep)

if __name__ == "__main__":
    nodes = [
        GraphNode("a", deps=["b", "c", "d"]),
        GraphNode("b", deps=["e"]),
        GraphNode("c", deps=["e", "f"]),
        GraphNode("d", deps=["i"]),
        GraphNode("e", deps=["g"]),
        GraphNode("f", deps=["g", "h"]),
        GraphNode("g", deps=["j"]),
        GraphNode("h", deps=["j", "k"]),
        GraphNode("i", deps=["k", "l"]),
        GraphNode("j", deps=[]),
        GraphNode("k", deps=[]),
        GraphNode("l", deps=[]),
    ]

    for c in [n.name for n in nodes]:
        dot = Digraph()
        dot.attr(rankdir='LR')
        ci_coloring(nodes, [c])
        assemble(nodes, dot)
        dot.render(c, format='png', cleanup=True)
        clear_attrs(nodes)
