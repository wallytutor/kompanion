# -*- coding: utf-8 -*-
import math
import gmsh


MESH_FILE = "honeycomb_1_12.msh"
N_FOLDS = 12


def main() -> None:
    gmsh.initialize()
    gmsh.open(MESH_FILE)


    if not (entities := gmsh.model.getEntities()):
        raise RuntimeError("No entities found in mesh model.")

    template_entities = list(entities)
    max_tag_by_dim = {dim: 0 for dim in (0, 1, 2, 3)}

    for dim, tag in entities:
        max_tag_by_dim[dim] = max(max_tag_by_dim[dim], tag)

    entity_data = {}
    for dim, tag in entities:
        node_tags, coords, _ = gmsh.model.mesh.getNodes(dim, tag, includeBoundary=False)
        element_types, element_tags, element_node_tags = gmsh.model.mesh.getElements(dim, tag)
        entity_data[(dim, tag)] = {
            "node_tags": list(node_tags),
            "coords": list(coords),
            "element_types": list(element_types),
            "element_tags": [list(tags) for tags in element_tags],
            "element_node_tags": [list(tags) for tags in element_node_tags],
        }

    next_node_tag       = gmsh.model.mesh.getMaxNodeTag() + 1
    next_element_tag    = gmsh.model.mesh.getMaxElementTag() + 1
    current_entity_data = entity_data

    for k in range(1, N_FOLDS):
        # Mirror the previously generated sector across the plane
        # at angle k*30°.
        alpha = k * 2.0 * math.pi / N_FOLDS
        c2 = math.cos(2.0 * alpha)
        s2 = math.sin(2.0 * alpha)

        node_map = {}
        entity_tag_map = {}
        next_entity_data = {}

        for dim in (0, 1, 2, 3):
            for old_dim, old_tag in template_entities:
                if old_dim != dim:
                    continue

                max_tag_by_dim[dim] += 1
                new_tag = max_tag_by_dim[dim]
                entity_tag_map[(old_dim, old_tag)] = new_tag

                gmsh.model.addDiscreteEntity(dim, new_tag)

                data = current_entity_data[(old_dim, old_tag)]
                old_node_tags = data["node_tags"]
                old_coords = data["coords"]

                if not old_node_tags:
                    continue

                new_node_tags = []
                new_coords = []

                for i, old_node in enumerate(old_node_tags):
                    if old_node in node_map:
                        new_node = node_map[old_node]
                    else:
                        new_node = next_node_tag
                        next_node_tag += 1
                        node_map[old_node] = new_node

                    x = old_coords[3 * i + 0]
                    y = old_coords[3 * i + 1]
                    z = old_coords[3 * i + 2]
                    xn = c2 * x + s2 * y
                    yn = s2 * x - c2 * y

                    new_node_tags.append(new_node)
                    new_coords.extend([xn, yn, z])

                gmsh.model.mesh.addNodes(dim, new_tag, new_node_tags, new_coords)

                next_entity_data[(old_dim, old_tag)] = {
                    "node_tags": new_node_tags,
                    "coords": new_coords,
                    "element_types": data["element_types"],
                    "element_tags": [],
                    "element_node_tags": [],
                }

        for old_dim, old_tag in template_entities:
            new_tag = entity_tag_map[(old_dim, old_tag)]
            data = current_entity_data[(old_dim, old_tag)]

            element_types = data["element_types"]
            element_tags = data["element_tags"]
            element_node_tags = data["element_node_tags"]

            if not element_types:
                continue

            new_element_tags_by_type = []
            new_element_nodes_by_type = []

            for tags, nodes in zip(element_tags, element_node_tags):
                new_tags = list(range(next_element_tag, next_element_tag + len(tags)))
                next_element_tag += len(tags)

                new_nodes = [node_map[node] for node in nodes]

                new_element_tags_by_type.append(new_tags)
                new_element_nodes_by_type.append(new_nodes)

            gmsh.model.mesh.addElements(
                old_dim,
                new_tag,
                element_types,
                new_element_tags_by_type,
                new_element_nodes_by_type,
            )

            last = next_entity_data[(old_dim, old_tag)]
            last["element_tags"] = new_element_tags_by_type
            last["element_node_tags"] = new_element_nodes_by_type

        current_entity_data = next_entity_data

    gmsh.option.setNumber("Mesh.SaveAll", 1)
    gmsh.write("display.msh")
    gmsh.fltk.run()
    gmsh.finalize()


if __name__ == "__main__":
    main()
