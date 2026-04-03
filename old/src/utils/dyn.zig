const std = @import("std");

/// Generates a dynamic dispatch interface from a struct of function pointers.
pub fn Interface(comptime MethodSigs: type) type {
    return struct {
        ptr: *anyopaque,
        vtable: *const VTable,

        const Self = @This();
        pub const Method = std.meta.FieldEnum(MethodSigs);

        const ErasedFn = *const fn (ptr: *anyopaque, args_ptr: *const anyopaque, ret_ptr: *anyopaque) void;

        pub const VTable = vtable_type: {
            const info = @typeInfo(MethodSigs).Struct;
            var fields: [info.fields.len]std.builtin.Type.StructField = undefined;
            for (info.fields, 0..) |field, i| {
                fields[i] = .{
                    .name = field.name,
                    .type = ErasedFn,
                    .default_value = null,
                    .is_comptime = false,
                    .alignment = @alignOf(ErasedFn),
                };
            }
            break :vtable_type @Type(.{ .Struct = .{
                .layout = .auto,
                .fields = &fields,
                .decls = &.{},
                .is_tuple = false,
            } });
        };

        pub fn init(pointer: anytype) Self {
            const PtrType = @TypeOf(pointer);
            const Impl = std.meta.Child(PtrType);

            const Gen = struct {
                const vtable: VTable = blk: {
                    var v: VTable = undefined;
                    const info = @typeInfo(MethodSigs).Struct;

                    for (info.fields) |field| {
                        if (!@hasDecl(Impl, field.name)) {
                            @compileError("Missing implementation: " ++ @typeName(Impl) ++ "." ++ field.name);
                        }

                        const FnType = @typeInfo(field.type).Pointer.child;
                        const fn_info = @typeInfo(FnType).Fn;

                        const Wrapper = struct {
                            fn call_erased(p: *anyopaque, args_p: *const anyopaque, ret_p: *anyopaque) void {
                                const typed_ptr: PtrType = @ptrCast(@alignCast(p));

                                const ArgsTuple = std.meta.ArgsTuple(FnType);
                                const args: *const ArgsTuple = @ptrCast(@alignCast(args_p));

                                const RetType = fn_info.return_type.?;

                                // Dynamically call the real function and pack the args back in
                                if (RetType == void) {
                                    @call(.auto, @field(Impl, field.name), .{typed_ptr} ++ args.*);
                                } else {
                                    const ret: *RetType = @ptrCast(@alignCast(ret_p));
                                    ret.* = @call(.auto, @field(Impl, field.name), .{typed_ptr} ++ args.*);
                                }
                            }
                        };

                        @field(v, field.name) = Wrapper.call_erased;
                    }
                    break :blk v;
                };
            };

            return .{
                .ptr = pointer,
                .vtable = &Gen.vtable,
            };
        }

        pub fn call(self: Self, comptime method: Method, args: anytype) ReturnType(method) {
            const method_name = @tagName(method);
            const func = @field(self.vtable, method_name);

            const ExpectedArgs = std.meta.ArgsTuple(GetFnType(method));
            const typed_args: ExpectedArgs = args;

            const RetType = ReturnType(method);

            if (RetType == void) {
                func(self.ptr, &typed_args, undefined);
            } else {
                var ret: RetType = undefined;
                func(self.ptr, &typed_args, &ret);
                return ret;
            }
        }

        fn GetFnType(comptime method: Method) type {
            const info = @typeInfo(MethodSigs).Struct;
            inline for (info.fields) |field| {
                if (std.mem.eql(u8, field.name, @tagName(method))) {
                    return @typeInfo(field.type).Pointer.child;
                }
            }
            unreachable;
        }

        fn ReturnType(comptime method: Method) type {
            return @typeInfo(GetFnType(method)).Fn.return_type.?;
        }
    };
}
