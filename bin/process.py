#! /usr/bin/env python3
from graphviz import Digraph
from software_graphs import GraphNode, assemble
import yaml
import argparse
import os


DEFAULT_GRAPH_ATTR = {
    "rankdir": "LR",
    "labelloc": "t"
}

parser = argparse.ArgumentParser()
parser.add_argument("input_file")
parser.add_argument("-p", "--parent", required=False, help="name of the graph to treat as the parent")
parser.add_argument("-o", "--output", required=False, help="name of file to generate")
parser.add_argument("-k", "--keep-graph", required=False, action="store_true", help="keep graph file")

args = parser.parse_args()

assert os.path.isfile(args.input_file)
with open(args.input_file, 'r') as f:
    data = yaml.safe_load(f)


def yaml_to_node(input):
    name = input.pop("name")
    deps = input.pop("deps", [])
    label = input.pop("label", None)
    rest = {}
    for key, value in input.items():
        rest[key] = value
        if key == "href":
            rest["fontcolor"] = "blue"
    return GraphNode(name, label, deps, **rest)

def subgraph_args(input):
    name = input.get("name")
    graph_attr = input.get("graph_attr", DEFAULT_GRAPH_ATTR)
    graph_attr["label"] = name
    args = {
        "name": name,
        "graph_attr": graph_attr,
    }
    cluster = input.pop("cluster", True)
    if cluster:
        args["name"] = f"cluster_{name}"
    return args


def _graph_inner_loop(ygraph, graph):
    ynodes = ygraph.get("nodes", [])
    nodes = [yaml_to_node(n) for n in ynodes]
    assemble(nodes, graph)
    if ygraph.get("graphs"):
        process_graph(ygraph, parent=graph)


def process_graph(data, parent=Digraph()):
    for ygraph in data["graphs"]:
        args = subgraph_args(ygraph)
        subgraph = Digraph(**args)
        _graph_inner_loop(ygraph, subgraph)
        parent.subgraph(subgraph)

    return parent


def find_parent(data, parent_name):
    """Query for parent breadth first"""
    graphs = data.get("graphs", {})
    check = lambda x: x["name"] == parent_name if x else False

    # search breadth
    for g in graphs:
        if check(g):
            return g
    for g in graphs:
        sub_g = find_parent(g, parent_name)
        if check(sub_g):
            return sub_g
    return None


parent = None
title = data.pop("title", f"graph_{args.input_file}")
if args.parent:
    start_data = find_parent(data, args.parent)
    assert start_data, "parent graph not found in file"
    parent = Digraph(**subgraph_args(start_data))
else:
    start_data = data
    parent = Digraph(name=title, graph_attr=DEFAULT_GRAPH_ATTR)

dot = process_graph(start_data, parent)
if args.output:
    title = args.output
dot.render(title, view=True, format="pdf", cleanup=(not args.keep_graph))
