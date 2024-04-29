extends Node

class_name TimelineStructureProcessor


const START_NODE_NAME: String = "StartNode"
const END_NODE_NAME: String = "EndNode"

var timeline_structure_data: Dictionary = {}

var complete_timeline_names: Array = []
var pending_timeline_names: Array = []
var locked_timeline_names: Array = []

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
    
    # TODO: set locked timelines connected to given timeline to pending
    

