extends GraphEdit

export var new_timeline_node_menu: PackedScene
export var new_timeline_node: PackedScene
export var new_operator_node: PackedScene
export var load_timeline_structure_menu: PackedScene
export var save_timeline_structure_as_menu: PackedScene

const OUTPUT_SLOT: int = 0
const INPUT_SLOT: int = 0
const START_NODE_NAME: String = "StartNode"
const END_NODE_NAME: String = "EndNode"
const TL_STRUCTURE_DATA_LOCATION: String = "res://gameData/timelineStructureData/"
# Default unnamed timeline structure name
const DEFAULT_TL_STRUCTURE_NAME: String = "UNNAMED"

onready var preview_mode_dimmer: ColorRect = get_node("PreviewModeDimmer")
onready var timeline_structure_name_lable: Label = get_node("MarginContainer/LabelTimelineStructureName")
# Timelein node graph datastructure
# Key: title, Value: TimelineNodeData
var timeline_structure_data: Dictionary = {}

# increment every time graph node child added
var next_node_id: int = 0
var preview_mode: bool = false
# Name that timeline structre is saved as
var timeline_structure_name: String = DEFAULT_TL_STRUCTURE_NAME
# true if active delete request
var delete_request: bool = false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    # TODO: check error?
    var error = SignalManager.connect("new_timeline_node_confirm_buton_pressed", self, "_on_new_timeline_node_confirm_buton_pressed")
    error = SignalManager.connect("timeline_graph_editor_save_selected", self, "_on_timeline_graph_editor_save_selected")
    SignalManager.connect("timeline_graph_editor_save_as_selected", self, "_on_timeline_graph_editor_save_as_selected")
    error = SignalManager.connect("timeline_graph_editor_load_selected", self, "_on_timeline_graph_editor_load_selected")
    error = SignalManager.connect("timeline_graph_editor_new_operator_selected", self, "_on_timeline_graph_editor_new_operator_selected")
    error = SignalManager.connect("timeline_graph_editor_new_graph_selected", self, "_on_timeline_graph_editor_new_graph_selected")
    error = SignalManager.connect("save_timeline_structure_as_confirm_button_pressed", self, "_on_save_timeline_structure_as_confirm_button_pressed")
    error = SignalManager.connect("load_timeline_structure_as_confirm_button_pressed", self, "_on_load_timeline_structure_as_confirm_button_pressed" )
    error = SignalManager.connect("graphNode_close_request", self, "_on_GraphNode_close_request")
    # Init start and end nodes. Same behavior as new graph?
    popualte_start_and_end()
    
    set_timeline_strucutre_name(timeline_structure_name)

func all_nodes_complete(names: Array) -> bool:
    var all_complete: bool = true
    for _name in names:
        var node_to_check: BasicGraphNode = get_node(_name)
        all_complete = all_complete && (node_to_check.preview_mode_state == BasicGraphNode.PreviewModeStates.COMPLETE)
    return all_complete
    

func any_nodes_complete(names: Array) -> bool:
    var any_complete: bool = false
    for _name in names:
        var node_to_check: BasicGraphNode = get_node(_name)
        any_complete = any_complete || (node_to_check.preview_mode_state == BasicGraphNode.PreviewModeStates.COMPLETE)
    return any_complete


func clear() -> void:
    
    next_node_id = 0
    clear_connections()
    
    # clear data structure
    for key in timeline_structure_data:
        timeline_structure_data = {}
    
    # Delete all children
    for child in get_children():
        if child is GraphNode:
            remove_child(child)
    
    
func disable_preview_mode()-> void:
    preview_mode = false
    #preview_mode_dimmer.visible = false
    #lighten background
    preview_mode_dimmer.color = Color(0, 0, 0, 0)
    
    # clear graphNode states
    for child in get_children():
        if child is BasicGraphNode:
            child.set_preview_mode_state(BasicGraphNode.PreviewModeStates.PENDING)

    
func enable_preview_mode()-> void:
    preview_mode = true
    
    # darken backdround
    preview_mode_dimmer.color = Color(0, 0, 0, .5)
    # set nodes to initital state. StartNode complete. All outputs of StartNode
    # pending. All other nodes locked 
    for child in get_children():
        if child is BasicGraphNode:
            child.set_preview_mode_state(BasicGraphNode.PreviewModeStates.LOCKED)

    get_node(START_NODE_NAME).set_preview_mode_state(BasicGraphNode.PreviewModeStates.COMPLETE)

    for node_name in timeline_structure_data[START_NODE_NAME].outputs:
        var node_to_change = get_node(node_name)
        if node_to_change.get_class() != "LogicGraphNode":
            node_to_change.set_preview_mode_state(BasicGraphNode.PreviewModeStates.PENDING)

    update_preview_mode()


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


func load_timeline_structure(structure_name: String) -> void:
    timeline_structure_name = structure_name.substr(0, structure_name.find("."))
    update_structre_name_label()
    var _dict: Dictionary = Utility.load_json(Utility.game_manager.TL_STRUCTURE_DATA_LOCATION+structure_name)
    
    var highest_id: int = -1
    
    clear()
    
    # Repopulate nodes 
    for key in _dict:
        # Make new data node 
        var new_data_node = TimelineNodeDataFactory.from_dict(_dict[key])
        
        # Remove duplicates from input and output arrays
        var inputs_dict: Dictionary = {}
        for input in new_data_node.inputs:
            inputs_dict[input] = 0
        new_data_node.inputs =  inputs_dict.keys() 
        
        var output_dict: Dictionary = {}
        for output in new_data_node.outputs:
            output_dict[output] = 0
        new_data_node.outputs = output_dict.keys()
        
        # add timeline nodes to data structure
        timeline_structure_data[key] = new_data_node
        
        # add nodes to graph edit. position based on connections
        # create new graph node
        var node_to_add: BasicGraphNode = null
        var name_overwrite = null
        
        if START_NODE_NAME == key:
            node_to_add = generate_start_node()
            add_child(node_to_add)
            name_overwrite = START_NODE_NAME
            
        elif END_NODE_NAME == key:
            node_to_add = generate_end_node()
            add_child(node_to_add)
            name_overwrite = END_NODE_NAME

        elif new_data_node is TimelineNodeTimelineData:
            node_to_add = new_timeline_node.instance()
            node_to_add.title = key
            name_overwrite = key
            add_child(node_to_add)
            node_to_add.set_timeline(new_data_node.timeline_name)
            node_to_add.set_location(new_data_node.location)
            node_to_add.set_character(new_data_node.character)
            node_to_add.show_close = true
            
        elif new_data_node is TimelineNodeData:
            node_to_add = new_operator_node.instance()
            add_child(node_to_add)
            node_to_add.title = key
            name_overwrite = key
            if key.begins_with("NOT"):
                node_to_add.operation = LogicGraphNode.Operation.NOT
            elif key.begins_with("AND"):
                node_to_add.operation = LogicGraphNode.Operation.AND
            elif key.begins_with("OR"):
                node_to_add.operation = LogicGraphNode.Operation.OR
            node_to_add.show_close = true
            
        if node_to_add:
            node_to_add.id = new_data_node["id"]
            if node_to_add.id > highest_id:
                highest_id = node_to_add.id
                
            node_to_add.offset = new_data_node["offset"]
            
            if name_overwrite:
                node_to_add.name = name_overwrite
        
    # connect nodes in data structure and in graph edit
    var children = get_children()
    for child in children:
        if child is GraphNode:
            var title = child.title
            for output in timeline_structure_data[title]["outputs"]:
                connect_node(title, OUTPUT_SLOT, output, INPUT_SLOT) 
    
    # update next id
    next_node_id = highest_id + 1


func popualte_start_and_end() -> void:
    # Add as graph edit children
    var start_node: BasicGraphNode= generate_start_node()
    add_child(start_node)
    var end_node: BasicGraphNode= generate_end_node()
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


func update_preview_mode() -> void:
    if !preview_mode:
        return
        
    # iterate from start to finish
    var nodes_to_check: Array = timeline_structure_data[START_NODE_NAME].outputs
    for node_name in nodes_to_check:
        var node_to_set = get_node(node_name)
        # check if operation node
        if node_to_set.get_class() == "LogicGraphNode":
            var inputs: Array = timeline_structure_data[node_to_set.name]["inputs"]
            match node_to_set.operation:
                LogicGraphNode.Operation.AND:
                    if all_nodes_complete(inputs):
                        node_to_set.set_preview_mode_state(BasicGraphNode.PreviewModeStates.COMPLETE)
                    else:
                        node_to_set.set_preview_mode_state(BasicGraphNode.PreviewModeStates.LOCKED)

                LogicGraphNode.Operation.NOT:
                    if all_nodes_complete(inputs):
                        node_to_set.set_preview_mode_state( BasicGraphNode.PreviewModeStates.LOCKED)
                    else:
                        node_to_set.set_preview_mode_state(BasicGraphNode.PreviewModeStates.COMPLETE)
                        
                LogicGraphNode.Operation.OR:
                    if any_nodes_complete(inputs):
                        node_to_set.set_preview_mode_state(BasicGraphNode.PreviewModeStates.COMPLETE)
                    else:
                        node_to_set.set_preview_mode_state(BasicGraphNode.PreviewModeStates.LOCKED)
                        
        elif node_to_set.preview_mode_state == BasicGraphNode.PreviewModeStates.COMPLETE:
            # Skip if node already marked complete
            continue
        # check all inputs complete
        elif all_nodes_complete(timeline_structure_data[node_to_set.name]["inputs"]):
            node_to_set.set_preview_mode_state(BasicGraphNode.PreviewModeStates.PENDING)
            
        else:
            node_to_set.set_preview_mode_state(BasicGraphNode.PreviewModeStates.LOCKED)
            
        # Add node's inputs to nodes_to_check
        nodes_to_check.append_array(timeline_structure_data[node_name].outputs)
        # Remove checked node
        #while nodes_to_check.has(node_name):
        #    nodes_to_check.erase(node_name)


func update_structre_name_label() -> void:
    timeline_structure_name_lable.text = timeline_structure_name


func save_timeline_structure() -> void:
    var dict_to_save: Dictionary = {}
    for timeline_name in timeline_structure_data:
        var timeline_node: TimelineNodeData = timeline_structure_data[timeline_name]
        dict_to_save[timeline_name] = timeline_node.to_dict()

    Utility.save_dict_as_json(Utility.game_manager.TL_STRUCTURE_DATA_LOCATION + timeline_structure_name + ".json", dict_to_save)


func save_timeline_structure_as() -> void:
    add_child(save_timeline_structure_as_menu.instance())


func set_timeline_strucutre_name(name: String) -> void:
    timeline_structure_name = name
    timeline_structure_name_lable.text = timeline_structure_name


func _on_ButtonNewNode_pressed() -> void:
    if preview_mode:
        print_debug("Cannot create new nodes in Preview Mode")
        return
        
    # Open a menu with fields to fill in for timeline node
    add_child(new_timeline_node_menu.instance())


func _on_CheckButtonPreviewMode_toggled(button_pressed: bool) -> void:
    if button_pressed:
        enable_preview_mode()
    else:
        disable_preview_mode()


func _on_GraphEdit__end_node_move() -> void:
    # save all graph node offsets
    for child in get_children():
        if child is GraphNode:
            timeline_structure_data[child.title].offset = child.offset


func _on_GraphEdit_connection_request(from: String, from_slot: int, to: String, to_slot: int) -> void:
    if preview_mode:
        print_debug("Cannot change connections in Preview Mode")
        return
    
    connect_node(from, from_slot, to, to_slot)
    
    var from_title = get_node(from).title
    var to_title = get_node(to).title
    # update prereq lists
    if !timeline_structure_data[from_title].outputs.has(to_title):
        timeline_structure_data[from_title].outputs.append(to_title)
    if !timeline_structure_data[to_title].inputs.has(from_title):
        timeline_structure_data[to_title].inputs.append(from_title)

#
#func _on_GraphEdit_child_entered_tree(node: Node) -> void:
#
#    if node is GraphNode:
#        node.connect("close_request",self, "_on_GraphNode_close_request")
#

func _on_GraphEdit_delete_nodes_request(nodes: Array) -> void:
    print_debug("Deleting nodes ", nodes)
    # remove connections
    # remove from inputs and outputs
    delete_request = true
    for node_name in nodes:
        
        var inputs: Array = timeline_structure_data[node_name].inputs.duplicate()
        for input in inputs:
            _on_GraphEdit_disconnection_request(input, OUTPUT_SLOT, node_name,INPUT_SLOT)
        var outputs: Array = timeline_structure_data[node_name].outputs.duplicate()
        for output in outputs:
            _on_GraphEdit_disconnection_request(node_name, INPUT_SLOT, output, OUTPUT_SLOT)
        timeline_structure_data.erase(node_name)
        get_node(node_name).queue_free()
    delete_request = false

func _on_GraphEdit_disconnection_request(from: String, from_slot: int, to: String, to_slot: int) -> void:
    if preview_mode:
        print_debug("Cannot change connections in Preview mode")
        return
        
    if get_node(from).selected or delete_request:
        disconnect_node(from, from_slot, to, to_slot)
        var from_title = get_node(from).title
        var to_title = get_node(to).title
        while timeline_structure_data[from_title].outputs.has(to_title):
            timeline_structure_data[from_title].outputs.erase(to_title)
        while timeline_structure_data[to_title].inputs.has(from_title):
            timeline_structure_data[to_title].inputs.erase(from_title)


func _on_GraphEdit_node_selected(node: BasicGraphNode) -> void:
    if !preview_mode:
        return
        
    #
    if node.preview_mode_state == BasicGraphNode.PreviewModeStates.PENDING:
        node.set_preview_mode_state(BasicGraphNode.PreviewModeStates.COMPLETE)
        # update other nodes
        update_preview_mode()
        

func _on_GraphNode_close_request(node_name: String):
    print_debug("Close Request on ", node_name)
    _on_GraphEdit_delete_nodes_request([node_name])


func _on_load_timeline_structure_as_confirm_button_pressed(structure_name: String) -> void:
    load_timeline_structure(structure_name)

func _on_new_timeline_node_confirm_buton_pressed(timeline: String, location: String, character: String):
    if preview_mode:
        print_debug("Cannot create new nodes in Preview Mode")
        return
    
    if get_node_or_null(timeline):
        print_debug("TimelineNode with name ", timeline, " already exists")
        return
        
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


func _on_save_timeline_structure_as_confirm_button_pressed(structure_name: String) -> void:
    timeline_structure_name = structure_name
    update_structre_name_label()
    save_timeline_structure()


func _on_timeline_graph_editor_new_graph_selected() -> void:
    if preview_mode:
        print_debug("Cannot create new nodes in Preview Mode")
        return
    # TODO: Popup saying all unsaved work will be lost
    
    clear()

    # Repopulate with start and end nodes
    popualte_start_and_end()


func _on_timeline_graph_editor_new_operator_selected(operation: int):

    if preview_mode:
        print_debug("Cannot create new nodes in Preview Mode")
        return

    var op_str: String = LogicGraphNode.Operation.keys()[operation]
    var node_name: String = op_str + "_" + String(next_node_id)
    
    if get_node_or_null(node_name):
        print_debug("LogicNode with name ", node_name, " already exits")
        return
    
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
    var load_menu_instance = load_timeline_structure_menu.instance()
    add_child(load_menu_instance)
    
    
    
    
    
# TODO: Save as timeline structure data
func _on_timeline_graph_editor_save_selected() -> void:
    if DEFAULT_TL_STRUCTURE_NAME == timeline_structure_name:
        save_timeline_structure_as()
    else:
        save_timeline_structure()
    


func _on_timeline_graph_editor_save_as_selected() -> void:
    # Popup asking for file name to save as
    save_timeline_structure_as()





