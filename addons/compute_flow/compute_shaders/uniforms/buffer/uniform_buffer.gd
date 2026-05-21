@icon("uid://bj7kvfplxme7p")
@tool
extends ComputeUniform
class_name UniformBuffer

@export_multiline var buffer_data := ""
## 自动对齐[br]
## 自动调整字段顺序，减少数据填充[br]
## 在需要完全自定义优化的情况下关闭
@export var auto_alignment = true
## 将 Field添加到data
@export_tool_button("add_to_data ") var add_field = _add_field_to_data
## 在编辑器中配置 data 数据[br]
## 该字典应该只在初始化时配置，在运行过程中禁止修改字典结构
@export var data: Dictionary = {}
@export var data_list:=[]
@export_storage var type_index:={}
@export var member_name:=""

@export_category("debug")
## debug 模式,会打印更多信息
@export var restart := false:
	set(value):
		restart = value
		if value:
			print("重置struct")
			set_values(data)
			await get_tree().create_timer(0.1).timeout
			restart = false

## 字段索引，用于快速查找
var _field_index: Dictionary = {}
## 字节化的buffer数据
var buffer_byte := PackedByteArray()
## 总数据大小
var data_size := 0

## 更新单个字段的值
func set_value(key: String, value: Variant) -> void:
	if debug:
		print("更新%s :%s"%[key,value])

		if not key in data:
			push_error("uniform buffer: 字段 '%s' 不存在" % key)
			return
		# 验证类型
		var expected_type = typeof(data[key])
		var actual_type = typeof(value)
		if expected_type != actual_type:
			push_error("uniform buffer: 字段 '%s' 类型错误" % key)
			return
	# 直接更新字节数组
	var value_bytes = ComputeFlowTool.get_value_bytes(value)
	var idx = _field_index.get(key)
	rd.buffer_update(rid,idx,value_bytes.size(),value_bytes)
	
## 批量更新多个字段
func set_values(updates: Dictionary = {}) -> void:
	if Engine.is_editor_hint():
		return
	if updates=={}:
		for key in data_list:
			set_value(key, data[key])
	for key in updates:
		if key in data:
			set_value(key, updates[key])

## 获取序列化的字节数据
func get_byte_array() -> PackedByteArray:
	return buffer_byte

func get_rd_uniform() -> RDUniform:
	if data_size == 0:
		_init_data()
	set_values()
	rd_uniform = RDUniform.new()
	rd_uniform.uniform_type = rd.UniformType.UNIFORM_TYPE_UNIFORM_BUFFER
	rd_uniform.binding = binding
	rd_uniform.add_id(rid)
	rd_change.emit()
	return rd_uniform

func get_declaration(set: int) -> String:
	var lines = PackedStringArray()
	lines.append("layout(std140, set = %s, binding = %s) uniform %s {" % [set, binding, uniform_name])
	
	for member in data_list:
		var value = data[member]
		var type_name = ComputeFlowTool.get_type_name(value)
		lines.append("    %s %s;" % [type_name, member])
		
	if member_name:
		lines.append("} %s;\n" % member_name)
	else:
		lines.append("};\n")
	return "\n".join(lines)

## 获取数据解析
func get_parsed_data() -> Dictionary:
	buffer_byte = rd.buffer_get_data(rid,0,data_size)
	return ComputeFlowTool.parse_value_bytes(buffer_byte,type_index,data_list)

## 解析文本并应用到配置
func _add_field_to_data() -> void:
	var datas:=  ComputeFlowTool.field_to_data(buffer_data,auto_alignment)
	data = datas[0]
	data_list= datas[1]
	type_index = datas[2]
	print("data :",data)
## 初始化字节数据
func _init_data()-> void:
	var template = ComputeFlowTool.generate_field_index(data,data_list,1)
	_field_index = template[0]
	data_size = template[1]
	buffer_byte.resize( data_size)
	if rid.is_valid():
		rd.free_rid(rid)
	rid = rd.uniform_buffer_create(data_size, buffer_byte)
