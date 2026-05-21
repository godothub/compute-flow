@icon("uid://d1fwfqxltnoqa")
@tool
extends ComputeUniform
class_name StorageBuffer

## buffer中的元素数量,当element_count为0 或者开启match_threads时,会自动匹配着色器最大粒子数量
@export var element_count:int = 0
@export var struct:=""
@export var member_name:=""

# -------------------------- 运行时数据 -------------------------- #
var data: Dictionary = {}
var data_list:=[]
var type_index:={}
## 字段索引，用于快速查找
var _field_index: Dictionary = {}
## 字节化的buffer数据
var buffer_byte := PackedByteArray()
## 总数据大小
var data_size := 0
## debug 模式,会打印更多信息
@export_category("debug")


#<=============================公有方法=============================>##
## 设置元素数量
func set_element_count(count:=element_count):
	element_count = count
	var global_size = black_board.global_size
	if element_count == 0:
		element_count = global_size.x * global_size.y * global_size.z

### 更新单个字段的值
func set_value(key: String, value: Variant) -> void:
	if debug:
		print("更新%s :%s"%[key,value])
		if not key in data:
			push_error("Storage buffer: 字段 '%s' 不存在" % key)
			return
		# 验证类型
		var expected_type = typeof(data[key])
		var actual_type = typeof(value)
		if expected_type != actual_type:
			push_error("Storage buffer: 字段 '%s' 类型错误" % key)
			return
	# 直接更新字节数组
	var value_bytes = ComputeFlowTool.get_value_bytes(value)
	
	var idx = _field_index.get(key)
	## 写入字节
	rd.buffer_update(rid,idx,value_bytes.size(),value_bytes)
## 批量更新多个字段
func set_values(updates: Dictionary = {}) -> void:
	if updates=={}:
		for key in data_list:
			set_value(key, data[key])
	for key in updates:
		if key in data:
			set_value(key, updates[key])
## 获取序列化的字节数据
func get_byte_array() -> PackedByteArray:
	return rd.buffer_get_data(rid)

func get_rd_uniform() -> RDUniform:
	if data_size == 0:
		_init_data()
	rd_uniform = RDUniform.new()
	rd_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	rd_uniform.binding = binding
	rd_uniform.add_id(rid)
	rd_change.emit()
	return rd_uniform

func get_declaration(set: int) -> String:
	var lines = PackedStringArray()
	lines.append("layout(set = %s, binding = %s, std430) buffer %s {" % [set, binding, uniform_name])
	if element_count==0:
		lines.append("    %s %s[];" % [struct, member_name])
	elif element_count == 1:
		lines.append("    %s %s;" % [struct, member_name])
	else :
		lines.append("    %s %s[%s];" % [struct, member_name,element_count])
	lines.append("};\n")
	return "\n".join(lines)

func get_parsed_data() -> Dictionary:
	return ComputeFlowTool.parse_value_bytes(buffer_byte,type_index,data_list)

## 初始化字节数据
func _init_data()-> void:
	set_element_count()
	var _struct:Struct = null
	for i in black_board.structs:
		if i.resource_name == struct:
			_struct=i
	data = _struct.data
	data_list= _struct.data_list
	type_index = _struct.type_index
	
	var template = ComputeFlowTool.generate_field_index(data,data_list,2)
	_field_index = template[0]
	data_size = template[1]*element_count

	buffer_byte.resize( data_size)
	rid = rd.storage_buffer_create(data_size, buffer_byte)
