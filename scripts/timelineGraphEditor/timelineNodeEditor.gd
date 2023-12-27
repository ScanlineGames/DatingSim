extends GraphEdit

export var new_timeline_node_menu: PackedScene
export var new_timeline_node: PackedScene
export var new_operator_node: PackedScene

const OUTPUT_SLOT: int = 0
const INPUT_SLOT: int = 0
const START_NODE_NAME: String = "StartNode"
const END_NODE_NAME: String = "EndNode"

# Timelein node graph datastructure
# Key: title, Value: TimelineNodeData
var timeline_structure_data: Dictionary = {}

# increment every time graph node child added
var next_node_id: int = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    # TODO: check error?
    var error = SignalManager.connect("new_timeline_node_confirm_buton_pressed", self, "_on_new_timeline_node_confirm_buton_pressed")
    error = SignalManager.connect("timeline_graph_editor_save_selected", self, "_on_timeline_graph_editor_save_selected")
    error = SignalManager.connect("timeline_graph_editor_load_selected", self, "_on_timeline_graph_editor_load_selected")
    error = SignalManager.connect("timeline_graph_editor_new_operator_selected", self, "_on_timeline_graph_editor_new_operator_selected")
    error = SignalManager.connect("timeline_graph_editor_new_graph_selected", self, "_on_timeline_graph_editor_new_graph_selected")

    # Init start and end nodes. Same behavior as new graph?
    popualte_start_and_end()
    

func clear() -> void:
    
    next_node_id = 0
    clear_connections()
    
    # clear data structure
    for key in timeline_structure_data:
        timeline_structure_data.erase(key)
    
    # Delete all children
    for child in get_children():
        if child is GraphNode:
            child.queue_free()
    
    
func generate_end_node() -> BasicGraphNode:
    var new_timeline_node_instance: BasicGraphNode = new_timeline_node.instance()
    new_timeline_node_instance.name = END_NODE_NAME
    new_timeline_node_instance.title = END_NODE_NAME
    new_timeline_node_instance.set_slot_enabled_right(OUTPUT_SLOT, false)
    new_timeline_node_instance.set_timeline(END_NODE_NAME)

    return new_timeline_node_instance


func generate_start_node() -> BasicGraphNode:
    var new_timeline_node_instance: BasicGraphNode = new_timeline_node.instance()
    new_timeline_node_instance.name = START_NODE_NAME
    new_timeline_node_instance.title = START_NODE_NAME
    new_timeline_node_instance.set_slot_enabled_left(INPUT_SLOT, false)
    new_timeline_node_instance.set_timeline(START_NODE_NAME)

    return new_timeline_node_instance


func popualte_start_and_end() -> void:
    # Add as graph edit children
    var start_node = generate_start_node()
    add_child(start_node)
    var end_node = generate_end_node()
    add_child(end_node)
    
    # Add to data structure    
    next_node_id = 0
    var start_node_data: TimelineNodeData = TimelineNodeDataFactory.create_tl_node_data(next_node_id)
    start_node.id = next_node_id
    next_node_id += 1

    var end_node_data: TimelineNodeData = TimelineNodeDataFactory.create_tl_node_data(next_node_id)
    end_node.id = next_node_id
    next_node_id += 1

    timeline_structure_data[start_node.title] = start_node_data
    timeline_structure_data[end_node.title] = end_node_data

func _on_ButtonNewNode_pressed() -> void:
    # Open a menu with fields to fill in for timeline node
    add_child(new_timeline_node_menu.instance())


func _on_GraphEdit_connection_request(from: String, from_slot: int, to: String, to_slot: int) -> void:
    connect_node(from, from_slot, to, to_slot)
    
    var from_title = get_node(from).title
    var to_title = get_node(to).title
    # update prereq lists
    timeline_structure_data[from_title].outputs.append(to_title)
    timeline_structure_data[to_title].inputs.append(from_title)


func _on_GraphEdit_disconnection_request(from: String, from_slot: int, to: String, to_slot: int) -> void:
    if get_node(from).selected:
        disconnect_node(from, from_slot, to, to_slot)
        var from_title = get_node(from).title
        var to_title = get_node(to).title
        timeline_structure_data[from_title].outputs.erase(to_title)
        timeline_structure_data[to_title].inputs.erase(from_title)


func _on_new_timeline_node_confirm_buton_pressed(timeline: String, location: String, character: String):
    var new_timeline_node_instance: TimelineGraphNode = new_timeline_node.instance() 
    add_child(new_timeline_node_instance)

    new_timeline_node_instance.id = next_node_id
    next_node_id += 1
    new_timeline_node_instance.title = timeline
    new_timeline_node_instance.name = timeline
    new_timeline_node_instance.set_timeline(timeline)
    new_timeline_node_instance.set_location(location)
    new_timeline_node_instance.set_character(character)
    new_timeline_node_instance.show_close = true
    
    # create new data node
    var timeline_node: TimelineNodeTimelineData = TimelineNodeDataFactory.create_tl_node_tl_data(new_timeline_node_instance.id, timeline, character, location)
    timeline_node.timeline_name = timeline
    timeline_node.location = location
    timeline_node.character = character
    
    timeline_structure_data[timeline] = timeline_node


func _on_timeline_graph_editor_new_graph_selected() -> void:
    # TODO: Popup saying all unsaved work will be lost
    
    clear()

    # Repopulate with start and end nodes
    popualte_start_and_end()


func _on_timeline_graph_editor_new_operator_selected(operation: int):
    var op_str: String = LogicGraphNode.Operation.keys()[operation]
    
    # create an new logic node with unique id and op_str as title
    var new_operator_node_instance: LogicGraphNode = new_operator_node.instance()
    add_child(new_operator_node_instance)
    new_operator_node_instance.id = next_node_id
    next_node_id += 1
    new_operator_node_instance.title = op_str + "_" + String(new_operator_node_instance.id)
    new_operator_node_instance.name = new_operator_node_instance.title
    new_operator_node_instance.show_close = true 
    
    # add to timeline nodes
    var new_data_operation_node: TimelineNodeData = TimelineNodeDataFactory.create_tl_node_data(new_operator_node_instance.id)
    timeline_structure_data[new_operator_node_instance.title] = new_data_operation_node

    
func _on_timeline_graph_editor_load_selected() -> void:
    # file explorer popup?
    var _dict: Dictionary = Utility.load_json("res://gameData/timelineStructureDataTest.json")
    
    #print_debug(_dict)
    
    clear()
    
    # Repopulate start and end node? 
    for key in _dict:
        # how do I know what type of node to make? 
        # from dict?
        var new_data_node = TimelineNodeDataFactory.from_dict(_dict[key])
        new_data_node.print()
        
        # add timeline nodes to data structure
        timeline_structure_data[key] = new_data_node
        
        # add nodes to graph edit. position based on connections
        #create new graph node
        var node_to_add: BasicGraphNode = null
        var name_overwrite = null
        
        if START_NODE_NAME == key:
            node_to_add = generate_start_node()
            name_overwrite = START_NODE_NAME
            
        elif END_NODE_NAME == key:
            node_to_add = generate_end_node()
            name_overwrite = END_NODE_NAME

        elif TimelineNodeTimelineData is new_data_node:
            node_to_add = new_timeline_node.instance()
            node_to_add.title = key
            name_overwrite = key
            node_to_add.show_close = true
            
        elif TimelineNodeData is new_data_node:
            node_to_add = new_operator_node.instance()
            node_to_add.title = key
            name_overwrite = key
            node_to_add.set_timeline(new_data_node["timeline"])
            node_to_add.set_location(new_data_node["location"])
            node_to_add.set_character(new_data_node["character"])
            node_to_add.show_close = true
            
        if node_to_add:
            node_to_add.id = new_data_node["id"]
            print_debug(node_to_add.name, " ", node_to_add.title)
            add_child(node_to_add)
            print_debug(node_to_add.name, " ", node_to_add.title)
            if name_overwrite:
                node_to_add.name = name_overwrite
            print_debug(node_to_add.name, " ", node_to_add.title)
    # connect nodes in data structure and in graph edit
    
    
    

# TODO: Save as timeline structure data
func _on_timeline_graph_editor_save_selected() -> void:
    var dict_to_save: Dictionary = {}
    for timeline_name in timeline_structure_data:
        var timeline_node: TimelineNodeData = timeline_structure_data[timeline_name]
        dict_to_save[timeline_name] = timeline_node.to_dict()

    Utility.save_dict_as_json("res://gameData/timelineStructureDataTest.json", dict_to_save)
