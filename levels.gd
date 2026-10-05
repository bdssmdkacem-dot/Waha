extends RefCounted
## Level data for Waha.
static func count() -> int:
	return 2
static func get_level(i: int) -> Dictionary:
	if i == 0: return _level_1()
	return _level_2()
static func _cell(x: float, y: float, z: float, goal: bool = false) -> Dictionary:
	return {"p": Vector3(x, y, z), "goal": goal}
static func _level_1() -> Dictionary:
	return {"name":"The Folded Bridge","hint":"Tap a tile to walk.\nTurn the crank to unfold the bridge.","cells":[_cell(0,0,0),_cell(1,0,0),_cell(2,0,0),_cell(3,0,0),_cell(4,0,0),_cell(5,0,0),_cell(5,1,0),_cell(5,2,0,true)],"edges":[[0,1],[1,2],[2,3],[3,4,"m1",1],[4,5,"m1",1],[5,6],[6,7]],"mechs":[{"id":"m1","kind":"fold","cell":4,"crank":Vector3(1.0,-1.8,0.0)}]}
static func _level_2() -> Dictionary:
	return {"name":"The Turning Tower","hint":"Slide the platform with the first crank.\nThen turn the tower to reach the oasis.","cells":[_cell(0,0,0),_cell(1,0,0),_cell(2,0,0),_cell(3,0,1),_cell(3,1,1),_cell(3,2,1),_cell(4,3,1),_cell(5,2,1),_cell(5,3,1),_cell(5,4,1),_cell(6,4,1),_cell(5,6,1),_cell(5,7,2,true)],"edges":[[0,1],[1,2],[2,3],[3,4],[4,5],[5,6,"m1",1],[6,7,"m1",1],[7,8],[8,9],[9,10],[10,11,"m2",1],[11,12]],"mechs":[{"id":"m1","kind":"slide","cell":6,"to":Vector3(4,2,1),"crank":Vector3(1.5,2.5,0.0)},{"id":"m2","kind":"rotate","cell":10,"pivot":Vector2(5,4),"angle":PI/2.0,"crank":Vector3(7.0,6.5,1.0)}]}
