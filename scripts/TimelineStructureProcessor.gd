extends Node

class_name TimelineStructureProcessor


const START_NODE_NAME: String = "StartNode"
const END_NODE_NAME: String = "EndNode"
const TL_STRUCTURE_DATA_LOCATION: String = "res://gameData/timelineStructureData/"
# Default unnamed timeline structure name
const DEFAULT_TL_STRUCTURE_NAME: String = "UNNAMED"

# Timeleine node graph datastructure
# Key: title, Value: TimelineNodeData
var timeline_structure_data: Dictionary = {}

var complete_timeline_names: Array = []
var pending_timeline_names: Array = []
var locked_timeline_names: Array = []

var timeline_structure_name: String = DEFAULT_TL_STRUCTURE_NAME

func _init(timeline_structure_json_dict: Dictionary = {}) -> void:
    
    for key in timeline_structure_json_dict:
        # Make new data node 
        var new_data_node = TimelineNodeDataFactory.from_dict(timeline_structure_json_dict[key])
        
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
        
    # init pending, locked, complete arrays
    for key in timeline_structure_data:
        # add nodes with no inputs to pending
        if len(timeline_structure_data[key].inputs) == 0 && \
           !pending_timeline_names.has(key):
            pending_timeline_names.append(key)
        else:
            if !locked_timeline_names.has(key):
                locked_timeline_names.append(key)
        
        

func add_timeline()->void:
    pass

func all_nodes_complete(names: Array) -> bool:
    var all_complete: bool = true
    for _name in names:
        all_complete = all_complete && complete_timeline_names.has(_name) 
    return all_complete
    

func any_nodes_complete(names: Array) -> bool:
    var any_complete: bool = false
    for _name in names:
        any_complete = any_complete || complete_timeline_names.has(_name) 
    return any_complete



func complete_pending(timeline_name: String)->void:
    # mark a pending timeline as complete. update status of timeline in structure
    if pending_timeline_names.has(timeline_name):
        complete_timeline_names.append(timeline_name)
        pending_timeline_names.remove(pending_timeline_names.find(timeline_name))
    else:
        printerr("Timeline not found in pending names: ", timeline_name)
    
    # set locked timelines connected to given timeline to pending
    for output_name in timeline_structure_data[timeline_name].outputs:
        if locked_timeline_names.has(output_name):
            locked_timeline_names.remove(locked_timeline_names.find(output_name))
            pending_timeline_names.append(output_name)
            
    # TODO: update logic nodes?


func connect_timelines(from_title: String, to_title: String)->void:
    if !timeline_structure_data[from_title].outputs.has(to_title):
        timeline_structure_data[from_title].outputs.append(to_title)
    if !timeline_structure_data[to_title].inputs.has(from_title):
        timeline_structure_data[to_title].inputs.append(from_title)

    
func clear() -> void:
    
    #next_node_id = 0
    #clear_connections()
    
    # clear data structure
    for key in timeline_structure_data:
        timeline_structure_data = {}

    complete_timeline_names = []
    pending_timeline_names = []
    locked_timeline_names = []

# update pending, locked, complete?
func update()->void:
    pass

func save_timeline_structure() -> void:
    var dict_to_save: Dictionary = {}
    for timeline_name in timeline_structure_data:
        var timeline_node: TimelineNodeData = timeline_structure_data[timeline_name]
        dict_to_save[timeline_name] = timeline_node.to_dict()

    Utility.save_dict_as_json(Utility.game_manager.TL_STRUCTURE_DATA_LOCATION + timeline_structure_name + ".json", dict_to_save)


func set_offset(timeline_name: String, new_offset: Vector2)->void:
    if timeline_structure_data.has(timeline_name):
        timeline_structure_data[timeline_name].offset = new_offset
    else:
        printerr(timeline_name," not found in timeline_structure_data")
