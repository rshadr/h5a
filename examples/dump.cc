/*
 * Copyright 2025 rshadr
 * See LICENSE for details
 */
#include <cstdlib>

#include <vector>
#include <string>

#include <h5a.h>


namespace ram {
} /* namespace ram */


namespace dom {


enum class NodeType {
  DOCTYPE,
  DOCUMENT,
  COMMENT,
  TEXT,
  ELEMENT,
};


class Node {
public:
  Node (NodeType node_type)
  {
    this->node_type = node_type;
  }

  virtual ~Node() = default;

public:
  std::vector<void *> child_nodes{};
  void *parent_node = nullptr;
  NodeType node_type;
};


class Document : public Node {
public:
  Document (void)
  : Node(NodeType::DOCUMENT)
  {
  }

  virtual ~Document() = default;

public:
  H5aQuirksMode mode = H5A_QUIRKS_MODE_NO_QUIRKS;
};


class Attribute {
public:
  Attribute (std::string name, std::string value)
  {
    this->name = name;
    this->value = value;
  }

  ~Attribute() = default;

public:
  std::string name;
  std::string value;
};


class Element : public Node {
public:
  Element (void)
  : Node(NodeType::ELEMENT)
  {
  }

  virtual ~Element() = default;

public:
  void *qualname = nullptr;
  std::vector<Attribute> attributes{};
};


class TemplateElement : public Element {
public:
  TemplateElement (void)
  : Element()
  {
  }

  virtual ~TemplateElement() = default;

public:
  void *template_contents = nullptr;
};


class Sink final {
public:
  Sink (void) = default;
  ~Sink() = default;

public:
  void
  parseError (char const *msg)
  {
    // ...
    (void) msg;
  }

  void
  setQuirksMode (H5aQuirksMode mode)
  {
    // ...
    (void) mode
  }


  void
  appendDoctypeToDocument (H5aStringView name,
                           H5aStringView public_id,
                           H5aStringView system_id)
  {
    // ...
    (void) name;
    (void) public_id;
    (void) system_id;
  }

  // ...

  H5aTag
  getTagByName (H5aStringView name)
  {
    // ...
    (void) name;
    return 0;
  }


public:
  static const H5aSinkVTable k_h5a_vtable;
};


const H5aSinkVTable Sink::k_h5a_vtable = {
  .finish = nullptr,
  .parse_error = nullptr,
  .get_document = nullptr,
  .get_template_contents = nullptr,
  .set_quirks_mode = nullptr,
  .same_node = nullptr,
  .elem_name = nullptr,
  .create_element = nullptr,
  .create_comment = nullptr,
  .append = nullptr,
  .append_before_sibling = nullptr,
  .append_doctype_to_document = nullptr,
  .add_attrs_if_missing = nullptr,
  .remove_from_parent = nullptr,
  .reparent_children = nullptr,
  .mark_script_already_started = nullptr,
  .complete_script = nullptr,
  .is_mathml_annotation_xml_integration_point = nullptr,

  .get_tag_by_name = nullptr,
  .destroy_handle = nullptr,
  .clone_handle = nullptr,
};


} /* namespace dom */


int
main (int argc, char *argv[])
{
  (void) argc;
  (void) argv;

  return EXIT_SUCCESS;
}

