extends GutTest

var timeline_structure_processor: TimelineStructureProcessor = null

func before_each():
    var _dict: Dictionary = Utility.load_json("res://gameData/timelineStructureData/test_timelineStructureDataTest.json")
    timeline_structure_processor = TimelineStructureProcessor.new(_dict)
    
    
func after_each():
    timeline_structure_processor.free()
    
    
func test_init():


    assert_ne(len(timeline_structure_processor.pending_timeline_names), 0, "TimelineStructureProcessor should have at least 1 pending scene after loading")

    
func test_complete_pending():
    var timeline_name: String = timeline_structure_processor.pending_timeline_names[0]
    
    assert_eq(timeline_structure_processor.complete_timeline_names.has(timeline_name), false, timeline_name + " should not be in complete list")
    timeline_structure_processor.complete_pending(timeline_name)
    assert_eq(timeline_structure_processor.complete_timeline_names.has(timeline_name), true, timeline_name + " should be in complete list")
    
    # check that outputs added to pending 
    var outputs_pending: bool = true
    for output_name in timeline_structure_processor.timeline_structure_data[timeline_name].outputs:
        outputs_pending = outputs_pending && timeline_structure_processor.pending_timeline_names.has(output_name)
        
    assert_eq(outputs_pending, true, timeline_name + " outputs should be in pending array")
