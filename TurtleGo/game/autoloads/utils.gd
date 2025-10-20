extends Node

static func remove_recursive(directory: String) -> Error:
	var err := Error.OK
	for dir_name in DirAccess.get_directories_at(directory):
		var err1 := remove_recursive(directory.path_join(dir_name))
		if err1 != Error.OK:
			err = err1

	for file_name in DirAccess.get_files_at(directory):
		var err2 := DirAccess.remove_absolute(directory.path_join(file_name))
		if err2 != Error.OK:
			err = err2

	var err3 := DirAccess.remove_absolute(directory)

	if err3 != Error.OK:
		err = err3

	return err
