/**
* meshoptimizer - version 0.25
*
* Copyright (C) 2016-2025, by Arseny Kapoulkine (arseny.kapoulkine@gmail.com)
* Report bugs and download new versions at https://github.com/zeux/meshoptimizer
*
* This library is distributed under the MIT License. See notice at the end of this file.
*/
package meshopt

import "core:c"

_ :: c

foreign import lib "meshopt.lib"

/* Version macro; major * 1000 + minor * 10 + patch */
MESHOPTIMIZER_VERSION :: 250 /* 0.25 */

// MESHOPTIMIZER_API :: 

// MESHOPTIMIZER_ALLOC_CALLCONV :: 

// MESHOPTIMIZER_EXPERIMENTAL :: MESHOPTIMIZER_API

/**
* Vertex attribute stream
* Each element takes size bytes, beginning at data, with stride controlling the spacing between successive elements (stride >= size).
*/
Stream :: struct {
	data:   rawptr,
	size:   c.size_t,
	stride: c.size_t,
}

/**
* Vertex buffer filter encoders
* These functions can be used to encode data in a format that meshopt_decodeFilter can decode
*
* meshopt_encodeFilterOct encodes unit vectors with K-bit (K <= 16) signed X/Y as an output.
* Each component is stored as an 8-bit or 16-bit normalized integer; stride must be equal to 4 or 8. W is preserved as is.
* Input data must contain 4 floats for every vector (count*4 total).
*
* meshopt_encodeFilterQuat encodes unit quaternions with K-bit (4 <= K <= 16) component encoding.
* Each component is stored as an 16-bit integer; stride must be equal to 8.
* Input data must contain 4 floats for every quaternion (count*4 total).
*
* meshopt_encodeFilterExp encodes arbitrary (finite) floating-point data with 8-bit exponent and K-bit integer mantissa (1 <= K <= 24).
* Exponent can be shared between all components of a given vector as defined by stride or all values of a given component; stride must be divisible by 4.
* Input data must contain stride/4 floats for every vector (count*stride/4 total).
*
* Experimental: meshopt_encodeFilterColor encodes RGBA color data by converting RGB to YCoCg color space with variable bit quantization.
* Each component is stored as an 8-bit or 16-bit integer; stride must be equal to 4 or 8.
* Input data must contain 4 floats for every color (count*4 total).
*/
Encode_Exp_Mode :: enum c.int {
	/* When encoding exponents, use separate values for each component (maximum quality) */
	Separate,

	/* When encoding exponents, use shared value for all components of each vector (better compression) */
	SharedVector,

	/* When encoding exponents, use shared value for each component of all vectors (best compression) */
	SharedComponent,

	/* When encoding exponents, use separate values for each component, but clamp to 0 (good quality if very small values are not important) */
	Clamped,
}

/**
* Simplification options
*/
Simplify_Options :: enum c.int {
	/* Do not move vertices that are located on the topological border (vertices on triangle edges that don't have a paired triangle). Useful for simplifying portions of the larger mesh. */
	LockBorder,

	/* Improve simplification performance assuming input indices are a sparse subset of the mesh. Note that error becomes relative to subset extents. */
	Sparse,

	/* Treat error limit and resulting error as absolute instead of relative to mesh extents. */
	ErrorAbsolute,

	/* Remove disconnected parts of the mesh during simplification incrementally, regardless of the topological restrictions inside components. */
	Prune,

	/* Experimental: Produce more regular triangle sizes and shapes during simplification, at some cost to geometric quality. */
	Regularize,

	/* Experimental: Allow collapses across attribute discontinuities, except for vertices that are tagged with meshopt_SimplifyVertex_Protect in vertex_lock. */
	Permissive,
}

Simplify_Options_Flags :: distinct bit_set[Simplify_Options; c.int]

/**
* Experimental: Simplification vertex flags/locks, for use in `vertex_lock` arrays in simplification APIs
*/
SimplifyVertex_Lock :: 1

SimplifyVertex_Protect :: 2

Vertex_Cache_Statistics :: struct {
	vertices_transformed: c.uint,
	warps_executed:       c.uint,
	acmr:                 f32, /* transformed vertices / triangle count; best case 0.5, worst case 3.0, optimum depends on topology */
	atvr:                 f32, /* transformed vertices / vertex count; best case 1.0, worst case 6.0, optimum is 1.0 (each vertex is transformed once) */
}

Vertex_Fetch_Statistics :: struct {
	bytes_fetched: c.uint,
	overfetch:     f32, /* fetched bytes / vertex buffer size; best case 1.0 (each byte is fetched once) */
}

Overdraw_Statistics :: struct {
	pixels_covered: c.uint,
	pixels_shaded:  c.uint,
	overdraw:       f32, /* shaded pixels / covered pixels; best case 1.0 */
}

Coverage_Statistics :: struct {
	coverage: [3]f32,
	extent:   f32, /* viewport size in mesh coordinates */
}

/**
* Meshlet is a small mesh cluster (subset) that consists of:
* - triangles, an 8-bit micro triangle (index) buffer, that for each triangle specifies three local vertices to use;
* - vertices, a 32-bit vertex indirection buffer, that for each local vertex specifies which mesh vertex to fetch vertex attributes from.
*
* For efficiency, meshlet triangles and vertices are packed into two large arrays; this structure contains offsets and counts to access the data.
*/
Meshlet :: struct {
	/* offsets within meshlet_vertices and meshlet_triangles arrays with meshlet data */
	vertex_offset: c.uint,
	triangle_offset: c.uint,

	/* number of vertices and triangles used in the meshlet; data is stored in consecutive range defined by offset and count */
	vertex_count: c.uint,
	triangle_count:  c.uint,
}

Bounds :: struct {
	/* bounding sphere, useful for frustum and occlusion culling */
	center: [3]f32,
	radius:         f32,

	/* normal cone, useful for backface culling */
	cone_apex: [3]f32,
	cone_axis:      [3]f32,
	cone_cutoff:    f32, /* = cos(angle/2) */

	/* normal cone axis and cutoff, stored in 8-bit SNORM format; decode using x/127.0 */
	cone_axis_s8: [3]c.schar,
	cone_cutoff_s8: c.schar,
}

@(default_calling_convention="c", link_prefix="meshopt_")
foreign lib {
	/**
	* Generates a vertex remap table from the vertex buffer and an optional index buffer and returns number of unique vertices
	* As a result, all vertices that are binary equivalent map to the same (new) location, with no gaps in the resulting sequence.
	* Resulting remap table maps old vertices to new vertices and can be used in meshopt_remapVertexBuffer/meshopt_remapIndexBuffer.
	* Note that binary equivalence considers all vertex_size bytes, including padding which should be zero-initialized.
	*
	* destination must contain enough space for the resulting remap table (vertex_count elements)
	* indices can be NULL if the input is unindexed
	*/
	generateVertexRemap :: proc(destination: ^c.uint, indices: ^c.uint, index_count: c.size_t, vertices: rawptr, vertex_count: c.size_t, vertex_size: c.size_t) -> c.size_t ---

	/**
	* Generates a vertex remap table from multiple vertex streams and an optional index buffer and returns number of unique vertices
	* As a result, all vertices that are binary equivalent map to the same (new) location, with no gaps in the resulting sequence.
	* Resulting remap table maps old vertices to new vertices and can be used in meshopt_remapVertexBuffer/meshopt_remapIndexBuffer.
	* To remap vertex buffers, you will need to call meshopt_remapVertexBuffer for each vertex stream.
	* Note that binary equivalence considers all size bytes in each stream, including padding which should be zero-initialized.
	*
	* destination must contain enough space for the resulting remap table (vertex_count elements)
	* indices can be NULL if the input is unindexed
	* stream_count must be <= 16
	*/
	generateVertexRemapMulti :: proc(destination: ^c.uint, indices: ^c.uint, index_count: c.size_t, vertex_count: c.size_t, streams: ^Stream, stream_count: c.size_t) -> c.size_t ---

	/**
	* Generates a vertex remap table from the vertex buffer and an optional index buffer and returns number of unique vertices
	* As a result, all vertices that are equivalent map to the same (new) location, with no gaps in the resulting sequence.
	* Equivalence is checked in two steps: vertex positions are compared for equality, and then the user-specified equality function is called (if provided).
	* Resulting remap table maps old vertices to new vertices and can be used in meshopt_remapVertexBuffer/meshopt_remapIndexBuffer.
	*
	* destination must contain enough space for the resulting remap table (vertex_count elements)
	* indices can be NULL if the input is unindexed
	* vertex_positions should have float3 position in the first 12 bytes of each vertex
	* callback can be NULL if no additional equality check is needed; otherwise, it should return 1 if vertices with specified indices are equivalent and 0 if they are not
	*/
	generateVertexRemapCustom :: proc(destination: ^c.uint, indices: ^c.uint, index_count: c.size_t, vertex_positions: ^f32, vertex_count: c.size_t, vertex_positions_stride: c.size_t, callback: proc "c" (rawptr, c.uint, c.uint) -> c.int, _context: rawptr) -> c.size_t ---

	/**
	* Generates vertex buffer from the source vertex buffer and remap table generated by meshopt_generateVertexRemap
	*
	* destination must contain enough space for the resulting vertex buffer (unique_vertex_count elements, returned by meshopt_generateVertexRemap)
	* vertex_count should be the initial vertex count and not the value returned by meshopt_generateVertexRemap
	*/
	remapVertexBuffer :: proc(destination: rawptr, vertices: rawptr, vertex_count: c.size_t, vertex_size: c.size_t, remap: ^c.uint) ---

	/**
	* Generate index buffer from the source index buffer and remap table generated by meshopt_generateVertexRemap
	*
	* destination must contain enough space for the resulting index buffer (index_count elements)
	* indices can be NULL if the input is unindexed
	*/
	remapIndexBuffer :: proc(destination: ^c.uint, indices: ^c.uint, index_count: c.size_t, remap: ^c.uint) ---

	/**
	* Generate index buffer that can be used for more efficient rendering when only a subset of the vertex attributes is necessary
	* All vertices that are binary equivalent (wrt first vertex_size bytes) map to the first vertex in the original vertex buffer.
	* This makes it possible to use the index buffer for Z pre-pass or shadowmap rendering, while using the original index buffer for regular rendering.
	* Note that binary equivalence considers all vertex_size bytes, including padding which should be zero-initialized.
	*
	* destination must contain enough space for the resulting index buffer (index_count elements)
	*/
	generateShadowIndexBuffer :: proc(destination: ^c.uint, indices: ^c.uint, index_count: c.size_t, vertices: rawptr, vertex_count: c.size_t, vertex_size: c.size_t, vertex_stride: c.size_t) ---

	/**
	* Generate index buffer that can be used for more efficient rendering when only a subset of the vertex attributes is necessary
	* All vertices that are binary equivalent (wrt specified streams) map to the first vertex in the original vertex buffer.
	* This makes it possible to use the index buffer for Z pre-pass or shadowmap rendering, while using the original index buffer for regular rendering.
	* Note that binary equivalence considers all size bytes in each stream, including padding which should be zero-initialized.
	*
	* destination must contain enough space for the resulting index buffer (index_count elements)
	* stream_count must be <= 16
	*/
	generateShadowIndexBufferMulti :: proc(destination: ^c.uint, indices: ^c.uint, index_count: c.size_t, vertex_count: c.size_t, streams: ^Stream, stream_count: c.size_t) ---

	/**
	* Generates a remap table that maps all vertices with the same position to the same (existing) index.
	* Similarly to meshopt_generateShadowIndexBuffer, this can be helpful to pre-process meshes for position-only rendering.
	* This can also be used to implement algorithms that require positional-only connectivity, such as hierarchical simplification.
	*
	* destination must contain enough space for the resulting remap table (vertex_count elements)
	* vertex_positions should have float3 position in the first 12 bytes of each vertex
	*/
	generatePositionRemap :: proc(destination: ^c.uint, vertex_positions: ^f32, vertex_count: c.size_t, vertex_positions_stride: c.size_t) ---

	/**
	* Generate index buffer that can be used as a geometry shader input with triangle adjacency topology
	* Each triangle is converted into a 6-vertex patch with the following layout:
	* - 0, 2, 4: original triangle vertices
	* - 1, 3, 5: vertices adjacent to edges 02, 24 and 40
	* The resulting patch can be rendered with geometry shaders using e.g. VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST_WITH_ADJACENCY.
	* This can be used to implement algorithms like silhouette detection/expansion and other forms of GS-driven rendering.
	*
	* destination must contain enough space for the resulting index buffer (index_count*2 elements)
	* vertex_positions should have float3 position in the first 12 bytes of each vertex
	*/
	generateAdjacencyIndexBuffer :: proc(destination: ^c.uint, indices: ^c.uint, index_count: c.size_t, vertex_positions: ^f32, vertex_count: c.size_t, vertex_positions_stride: c.size_t) ---

	/**
	* Generate index buffer that can be used for PN-AEN tessellation with crack-free displacement
	* Each triangle is converted into a 12-vertex patch with the following layout:
	* - 0, 1, 2: original triangle vertices
	* - 3, 4: opposing edge for edge 0, 1
	* - 5, 6: opposing edge for edge 1, 2
	* - 7, 8: opposing edge for edge 2, 0
	* - 9, 10, 11: dominant vertices for corners 0, 1, 2
	* The resulting patch can be rendered with hardware tessellation using PN-AEN and displacement mapping.
	* See "Tessellation on Any Budget" (John McDonald, GDC 2011) for implementation details.
	*
	* destination must contain enough space for the resulting index buffer (index_count*4 elements)
	* vertex_positions should have float3 position in the first 12 bytes of each vertex
	*/
	generateTessellationIndexBuffer :: proc(destination: ^c.uint, indices: ^c.uint, index_count: c.size_t, vertex_positions: ^f32, vertex_count: c.size_t, vertex_positions_stride: c.size_t) ---

	/**
	* Generate index buffer that can be used for visibility buffer rendering and returns the size of the reorder table
	* Each triangle's provoking vertex index is equal to primitive id; this allows passing it to the fragment shader using flat/nointerpolation attribute.
	* This is important for performance on hardware where primitive id can't be accessed efficiently in fragment shader.
	* The reorder table stores the original vertex id for each vertex in the new index buffer, and should be used in the vertex shader to load vertex data.
	* The provoking vertex is assumed to be the first vertex in the triangle; if this is not the case (OpenGL), rotate each triangle (abc -> bca) before rendering.
	* For maximum efficiency the input index buffer should be optimized for vertex cache first.
	*
	* destination must contain enough space for the resulting index buffer (index_count elements)
	* reorder must contain enough space for the worst case reorder table (vertex_count + index_count/3 elements)
	*/
	generateProvokingIndexBuffer :: proc(destination: ^c.uint, reorder: ^c.uint, indices: ^c.uint, index_count: c.size_t, vertex_count: c.size_t) -> c.size_t ---

	/**
	* Vertex transform cache optimizer
	* Reorders indices to reduce the number of GPU vertex shader invocations
	* If index buffer contains multiple ranges for multiple draw calls, this functions needs to be called on each range individually.
	*
	* destination must contain enough space for the resulting index buffer (index_count elements)
	*/
	optimizeVertexCache :: proc(destination: ^c.uint, indices: ^c.uint, index_count: c.size_t, vertex_count: c.size_t) ---

	/**
	* Vertex transform cache optimizer for strip-like caches
	* Produces inferior results to meshopt_optimizeVertexCache from the GPU vertex cache perspective
	* However, the resulting index order is more optimal if the goal is to reduce the triangle strip length or improve compression efficiency
	*
	* destination must contain enough space for the resulting index buffer (index_count elements)
	*/
	optimizeVertexCacheStrip :: proc(destination: ^c.uint, indices: ^c.uint, index_count: c.size_t, vertex_count: c.size_t) ---

	/**
	* Vertex transform cache optimizer for FIFO caches
	* Reorders indices to reduce the number of GPU vertex shader invocations
	* Generally takes ~3x less time to optimize meshes but produces inferior results compared to meshopt_optimizeVertexCache
	* If index buffer contains multiple ranges for multiple draw calls, this functions needs to be called on each range individually.
	*
	* destination must contain enough space for the resulting index buffer (index_count elements)
	* cache_size should be less than the actual GPU cache size to avoid cache thrashing
	*/
	optimizeVertexCacheFifo :: proc(destination: ^c.uint, indices: ^c.uint, index_count: c.size_t, vertex_count: c.size_t, cache_size: c.uint) ---

	/**
	* Overdraw optimizer
	* Reorders indices to reduce the number of GPU vertex shader invocations and the pixel overdraw
	* If index buffer contains multiple ranges for multiple draw calls, this functions needs to be called on each range individually.
	*
	* destination must contain enough space for the resulting index buffer (index_count elements)
	* indices must contain index data that is the result of meshopt_optimizeVertexCache (*not* the original mesh indices!)
	* vertex_positions should have float3 position in the first 12 bytes of each vertex
	* threshold indicates how much the overdraw optimizer can degrade vertex cache efficiency (1.05 = up to 5%) to reduce overdraw more efficiently
	*/
	optimizeOverdraw :: proc(destination: ^c.uint, indices: ^c.uint, index_count: c.size_t, vertex_positions: ^f32, vertex_count: c.size_t, vertex_positions_stride: c.size_t, threshold: f32) ---

	/**
	* Vertex fetch cache optimizer
	* Reorders vertices and changes indices to reduce the amount of GPU memory fetches during vertex processing
	* Returns the number of unique vertices, which is the same as input vertex count unless some vertices are unused
	* This functions works for a single vertex stream; for multiple vertex streams, use meshopt_optimizeVertexFetchRemap + meshopt_remapVertexBuffer for each stream.
	*
	* destination must contain enough space for the resulting vertex buffer (vertex_count elements)
	* indices is used both as an input and as an output index buffer
	*/
	optimizeVertexFetch :: proc(destination: rawptr, indices: ^c.uint, index_count: c.size_t, vertices: rawptr, vertex_count: c.size_t, vertex_size: c.size_t) -> c.size_t ---

	/**
	* Vertex fetch cache optimizer
	* Generates vertex remap to reduce the amount of GPU memory fetches during vertex processing
	* Returns the number of unique vertices, which is the same as input vertex count unless some vertices are unused
	* The resulting remap table should be used to reorder vertex/index buffers using meshopt_remapVertexBuffer/meshopt_remapIndexBuffer
	*
	* destination must contain enough space for the resulting remap table (vertex_count elements)
	*/
	optimizeVertexFetchRemap :: proc(destination: ^c.uint, indices: ^c.uint, index_count: c.size_t, vertex_count: c.size_t) -> c.size_t ---

	/**
	* Index buffer encoder
	* Encodes index data into an array of bytes that is generally much smaller (<1.5 bytes/triangle) and compresses better (<1 bytes/triangle) compared to original.
	* Input index buffer must represent a triangle list.
	* Returns encoded data size on success, 0 on error; the only error condition is if buffer doesn't have enough space
	* For maximum efficiency the index buffer being encoded has to be optimized for vertex cache and vertex fetch first.
	*
	* buffer must contain enough space for the encoded index buffer (use meshopt_encodeIndexBufferBound to compute worst case size)
	*/
	encodeIndexBuffer      :: proc(buffer: ^c.uchar, buffer_size: c.size_t, indices: ^c.uint, index_count: c.size_t) -> c.size_t ---
	encodeIndexBufferBound :: proc(index_count: c.size_t, vertex_count: c.size_t) -> c.size_t ---

	/**
	* Set index encoder format version (defaults to 1)
	*
	* version must specify the data format version to encode; valid values are 0 (decodable by all library versions) and 1 (decodable by 0.14+)
	*/
	encodeIndexVersion :: proc(version: c.int) ---

	/**
	* Index buffer decoder
	* Decodes index data from an array of bytes generated by meshopt_encodeIndexBuffer
	* Returns 0 if decoding was successful, and an error code otherwise
	* The decoder is safe to use for untrusted input, but it may produce garbage data (e.g. out of range indices).
	*
	* destination must contain enough space for the resulting index buffer (index_count elements)
	*/
	decodeIndexBuffer :: proc(destination: rawptr, index_count: c.size_t, index_size: c.size_t, buffer: ^c.uchar, buffer_size: c.size_t) -> c.int ---

	/**
	* Get encoded index format version
	* Returns format version of the encoded index buffer/sequence, or -1 if the buffer header is invalid
	* Note that a non-negative value doesn't guarantee that the buffer will be decoded correctly if the input is malformed.
	*/
	decodeIndexVersion :: proc(buffer: ^c.uchar, buffer_size: c.size_t) -> c.int ---

	/**
	* Index sequence encoder
	* Encodes index sequence into an array of bytes that is generally smaller and compresses better compared to original.
	* Input index sequence can represent arbitrary topology; for triangle lists meshopt_encodeIndexBuffer is likely to be better.
	* Returns encoded data size on success, 0 on error; the only error condition is if buffer doesn't have enough space
	*
	* buffer must contain enough space for the encoded index sequence (use meshopt_encodeIndexSequenceBound to compute worst case size)
	*/
	encodeIndexSequence      :: proc(buffer: ^c.uchar, buffer_size: c.size_t, indices: ^c.uint, index_count: c.size_t) -> c.size_t ---
	encodeIndexSequenceBound :: proc(index_count: c.size_t, vertex_count: c.size_t) -> c.size_t ---

	/**
	* Index sequence decoder
	* Decodes index data from an array of bytes generated by meshopt_encodeIndexSequence
	* Returns 0 if decoding was successful, and an error code otherwise
	* The decoder is safe to use for untrusted input, but it may produce garbage data (e.g. out of range indices).
	*
	* destination must contain enough space for the resulting index sequence (index_count elements)
	*/
	decodeIndexSequence :: proc(destination: rawptr, index_count: c.size_t, index_size: c.size_t, buffer: ^c.uchar, buffer_size: c.size_t) -> c.int ---

	/**
	* Vertex buffer encoder
	* Encodes vertex data into an array of bytes that is generally smaller and compresses better compared to original.
	* Returns encoded data size on success, 0 on error; the only error condition is if buffer doesn't have enough space
	* This function works for a single vertex stream; for multiple vertex streams, call meshopt_encodeVertexBuffer for each stream.
	* Note that all vertex_size bytes of each vertex are encoded verbatim, including padding which should be zero-initialized.
	* For maximum efficiency the vertex buffer being encoded has to be quantized and optimized for locality of reference (cache/fetch) first.
	*
	* buffer must contain enough space for the encoded vertex buffer (use meshopt_encodeVertexBufferBound to compute worst case size)
	* vertex_size must be a multiple of 4 (and <= 256)
	*/
	encodeVertexBuffer      :: proc(buffer: ^c.uchar, buffer_size: c.size_t, vertices: rawptr, vertex_count: c.size_t, vertex_size: c.size_t) -> c.size_t ---
	encodeVertexBufferBound :: proc(vertex_count: c.size_t, vertex_size: c.size_t) -> c.size_t ---

	/**
	* Vertex buffer encoder
	* Encodes vertex data just like meshopt_encodeVertexBuffer, but allows to override compression level.
	* For compression level to take effect, the vertex encoding version must be set to 1.
	* The default compression level implied by meshopt_encodeVertexBuffer is 2.
	*
	* buffer must contain enough space for the encoded vertex buffer (use meshopt_encodeVertexBufferBound to compute worst case size)
	* vertex_size must be a multiple of 4 (and <= 256)
	* level should be in the range [0, 3] with 0 being the fastest and 3 being the slowest and producing the best compression ratio.
	* version should be -1 to use the default version (specified via meshopt_encodeVertexVersion), or 0/1 to override the version; per above, level won't take effect if version is 0.
	*/
	encodeVertexBufferLevel :: proc(buffer: ^c.uchar, buffer_size: c.size_t, vertices: rawptr, vertex_count: c.size_t, vertex_size: c.size_t, level: c.int, version: c.int) -> c.size_t ---

	/**
	* Set vertex encoder format version (defaults to 1)
	*
	* version must specify the data format version to encode; valid values are 0 (decodable by all library versions) and 1 (decodable by 0.23+)
	*/
	encodeVertexVersion :: proc(version: c.int) ---

	/**
	* Vertex buffer decoder
	* Decodes vertex data from an array of bytes generated by meshopt_encodeVertexBuffer
	* Returns 0 if decoding was successful, and an error code otherwise
	* The decoder is safe to use for untrusted input, but it may produce garbage data.
	*
	* destination must contain enough space for the resulting vertex buffer (vertex_count * vertex_size bytes)
	* vertex_size must be a multiple of 4 (and <= 256)
	*/
	decodeVertexBuffer :: proc(destination: rawptr, vertex_count: c.size_t, vertex_size: c.size_t, buffer: ^c.uchar, buffer_size: c.size_t) -> c.int ---

	/**
	* Get encoded vertex format version
	* Returns format version of the encoded vertex buffer, or -1 if the buffer header is invalid
	* Note that a non-negative value doesn't guarantee that the buffer will be decoded correctly if the input is malformed.
	*/
	decodeVertexVersion :: proc(buffer: ^c.uchar, buffer_size: c.size_t) -> c.int ---

	/**
	* Vertex buffer filters
	* These functions can be used to filter output of meshopt_decodeVertexBuffer in-place.
	*
	* meshopt_decodeFilterOct decodes octahedral encoding of a unit vector with K-bit (K <= 16) signed X/Y as an input; Z must store 1.0f.
	* Each component is stored as an 8-bit or 16-bit normalized integer; stride must be equal to 4 or 8. W is preserved as is.
	*
	* meshopt_decodeFilterQuat decodes 3-component quaternion encoding with K-bit (4 <= K <= 16) component encoding and a 2-bit component index indicating which component to reconstruct.
	* Each component is stored as an 16-bit integer; stride must be equal to 8.
	*
	* meshopt_decodeFilterExp decodes exponential encoding of floating-point data with 8-bit exponent and 24-bit integer mantissa as 2^E*M.
	* Each 32-bit component is decoded in isolation; stride must be divisible by 4.
	*
	* Experimental: meshopt_decodeFilterColor decodes YCoCg (+A) color encoding where RGB is converted to YCoCg space with variable bit quantization.
	* Each component is stored as an 8-bit or 16-bit normalized integer; stride must be equal to 4 or 8.
	*/
	decodeFilterOct   :: proc(buffer: rawptr, count: c.size_t, stride: c.size_t) ---
	decodeFilterQuat  :: proc(buffer: rawptr, count: c.size_t, stride: c.size_t) ---
	decodeFilterExp   :: proc(buffer: rawptr, count: c.size_t, stride: c.size_t) ---
	decodeFilterColor :: proc(buffer: rawptr, count: c.size_t, stride: c.size_t) ---
	encodeFilterOct   :: proc(destination: rawptr, count: c.size_t, stride: c.size_t, bits: c.int, data: ^f32) ---
	encodeFilterQuat  :: proc(destination: rawptr, count: c.size_t, stride: c.size_t, bits: c.int, data: ^f32) ---
	encodeFilterExp   :: proc(destination: rawptr, count: c.size_t, stride: c.size_t, bits: c.int, data: ^f32, mode: Encode_Exp_Mode) ---
	encodeFilterColor :: proc(destination: rawptr, count: c.size_t, stride: c.size_t, bits: c.int, data: ^f32) ---

	/**
	* Mesh simplifier
	* Reduces the number of triangles in the mesh, attempting to preserve mesh appearance as much as possible
	* The algorithm tries to preserve mesh topology and can stop short of the target goal based on topology constraints or target error.
	* If not all attributes from the input mesh are needed, it's recommended to reindex the mesh without them prior to simplification.
	* Returns the number of indices after simplification, with destination containing new index data
	*
	* The resulting index buffer references vertices from the original vertex buffer.
	* If the original vertex data isn't needed, creating a compact vertex buffer using meshopt_optimizeVertexFetch is recommended.
	*
	* destination must contain enough space for the target index buffer, worst case is index_count elements (*not* target_index_count)!
	* vertex_positions should have float3 position in the first 12 bytes of each vertex
	* target_error represents the error relative to mesh extents that can be tolerated, e.g. 0.01 = 1% deformation; value range [0..1]
	* options must be a bitmask composed of meshopt_SimplifyX options; 0 is a safe default
	* result_error can be NULL; when it's not NULL, it will contain the resulting (relative) error after simplification
	*/
	simplify :: proc(destination: ^c.uint, indices: ^c.uint, index_count: c.size_t, vertex_positions: ^f32, vertex_count: c.size_t, vertex_positions_stride: c.size_t, target_index_count: c.size_t, target_error: f32, options: Simplify_Options_Flags, result_error: ^f32) -> c.size_t ---

	/**
	* Mesh simplifier with attribute metric
	* Reduces the number of triangles in the mesh, attempting to preserve mesh appearance as much as possible.
	* Similar to meshopt_simplify, but incorporates attribute values into the error metric used to prioritize simplification order.
	* The algorithm tries to preserve mesh topology and can stop short of the target goal based on topology constraints or target error.
	* If not all attributes from the input mesh are needed, it's recommended to reindex the mesh without them prior to simplification.
	* Returns the number of indices after simplification, with destination containing new index data
	*
	* The resulting index buffer references vertices from the original vertex buffer.
	* If the original vertex data isn't needed, creating a compact vertex buffer using meshopt_optimizeVertexFetch is recommended.
	* Note that the number of attributes with non-zero weights affects memory requirements and running time.
	*
	* destination must contain enough space for the target index buffer, worst case is index_count elements (*not* target_index_count)!
	* vertex_positions should have float3 position in the first 12 bytes of each vertex
	* vertex_attributes should have attribute_count floats for each vertex
	* attribute_weights should have attribute_count floats in total; the weights determine relative priority of attributes between each other and wrt position
	* attribute_count must be <= 32
	* vertex_lock can be NULL; when it's not NULL, it should have a value for each vertex; 1 denotes vertices that can't be moved
	* target_error represents the error relative to mesh extents that can be tolerated, e.g. 0.01 = 1% deformation; value range [0..1]
	* options must be a bitmask composed of meshopt_SimplifyX options; 0 is a safe default
	* result_error can be NULL; when it's not NULL, it will contain the resulting (relative) error after simplification
	*/
	simplifyWithAttributes :: proc(destination: ^c.uint, indices: ^c.uint, index_count: c.size_t, vertex_positions: ^f32, vertex_count: c.size_t, vertex_positions_stride: c.size_t, vertex_attributes: ^f32, vertex_attributes_stride: c.size_t, attribute_weights: ^f32, attribute_count: c.size_t, vertex_lock: ^c.uchar, target_index_count: c.size_t, target_error: f32, options: Simplify_Options_Flags, result_error: ^f32) -> c.size_t ---

	/**
	* Experimental: Mesh simplifier with position/attribute update
	* Reduces the number of triangles in the mesh, attempting to preserve mesh appearance as much as possible.
	* Similar to meshopt_simplifyWithAttributes, but destructively updates positions and attribute values for optimal appearance.
	* The algorithm tries to preserve mesh topology and can stop short of the target goal based on topology constraints or target error.
	* If not all attributes from the input mesh are needed, it's recommended to reindex the mesh without them prior to simplification.
	* Returns the number of indices after simplification, indices are destructively updated with new index data
	*
	* The updated index buffer references vertices from the original vertex buffer, however the vertex positions and attributes are updated in-place.
	* Creating a compact vertex buffer using meshopt_optimizeVertexFetch is recommended; if the original vertex data is needed, it should be copied before simplification.
	* Note that the number of attributes with non-zero weights affects memory requirements and running time. Attributes with zero weights are not updated.
	*
	* vertex_positions should have float3 position in the first 12 bytes of each vertex
	* vertex_attributes should have attribute_count floats for each vertex
	* attribute_weights should have attribute_count floats in total; the weights determine relative priority of attributes between each other and wrt position
	* attribute_count must be <= 32
	* vertex_lock can be NULL; when it's not NULL, it should have a value for each vertex; 1 denotes vertices that can't be moved
	* target_error represents the error relative to mesh extents that can be tolerated, e.g. 0.01 = 1% deformation; value range [0..1]
	* options must be a bitmask composed of meshopt_SimplifyX options; 0 is a safe default
	* result_error can be NULL; when it's not NULL, it will contain the resulting (relative) error after simplification
	*/
	simplifyWithUpdate :: proc(indices: ^c.uint, index_count: c.size_t, vertex_positions: ^f32, vertex_count: c.size_t, vertex_positions_stride: c.size_t, vertex_attributes: ^f32, vertex_attributes_stride: c.size_t, attribute_weights: ^f32, attribute_count: c.size_t, vertex_lock: ^c.uchar, target_index_count: c.size_t, target_error: f32, options: Simplify_Options_Flags, result_error: ^f32) -> c.size_t ---

	/**
	* Mesh simplifier (sloppy)
	* Reduces the number of triangles in the mesh, sacrificing mesh appearance for simplification performance
	* The algorithm doesn't preserve mesh topology but can stop short of the target goal based on target error.
	* Returns the number of indices after simplification, with destination containing new index data
	* The resulting index buffer references vertices from the original vertex buffer.
	* If the original vertex data isn't needed, creating a compact vertex buffer using meshopt_optimizeVertexFetch is recommended.
	*
	* destination must contain enough space for the target index buffer, worst case is index_count elements (*not* target_index_count)!
	* vertex_positions should have float3 position in the first 12 bytes of each vertex
	* vertex_lock can be NULL; when it's not NULL, it should have a value for each vertex; vertices that can't be moved should set 1 consistently for all indices with the same position
	* target_error represents the error relative to mesh extents that can be tolerated, e.g. 0.01 = 1% deformation; value range [0..1]
	* result_error can be NULL; when it's not NULL, it will contain the resulting (relative) error after simplification
	*/
	simplifySloppy :: proc(destination: ^c.uint, indices: ^c.uint, index_count: c.size_t, vertex_positions: ^f32, vertex_count: c.size_t, vertex_positions_stride: c.size_t, vertex_lock: ^c.uchar, target_index_count: c.size_t, target_error: f32, result_error: ^f32) -> c.size_t ---

	/**
	* Mesh simplifier (pruner)
	* Reduces the number of triangles in the mesh by removing small isolated parts of the mesh
	* Returns the number of indices after simplification, with destination containing new index data
	* The resulting index buffer references vertices from the original vertex buffer.
	* If the original vertex data isn't needed, creating a compact vertex buffer using meshopt_optimizeVertexFetch is recommended.
	*
	* destination must contain enough space for the target index buffer, worst case is index_count elements
	* vertex_positions should have float3 position in the first 12 bytes of each vertex
	* target_error represents the error relative to mesh extents that can be tolerated, e.g. 0.01 = 1% deformation; value range [0..1]
	*/
	simplifyPrune :: proc(destination: ^c.uint, indices: ^c.uint, index_count: c.size_t, vertex_positions: ^f32, vertex_count: c.size_t, vertex_positions_stride: c.size_t, target_error: f32) -> c.size_t ---

	/**
	* Point cloud simplifier
	* Reduces the number of points in the cloud to reach the given target
	* Returns the number of points after simplification, with destination containing new index data
	* The resulting index buffer references vertices from the original vertex buffer.
	* If the original vertex data isn't needed, creating a compact vertex buffer using meshopt_optimizeVertexFetch is recommended.
	*
	* destination must contain enough space for the target index buffer (target_vertex_count elements)
	* vertex_positions should have float3 position in the first 12 bytes of each vertex
	* vertex_colors can be NULL; when it's not NULL, it should have float3 color in the first 12 bytes of each vertex
	* color_weight determines relative priority of color wrt position; 1.0 is a safe default
	*/
	simplifyPoints :: proc(destination: ^c.uint, vertex_positions: ^f32, vertex_count: c.size_t, vertex_positions_stride: c.size_t, vertex_colors: ^f32, vertex_colors_stride: c.size_t, color_weight: f32, target_vertex_count: c.size_t) -> c.size_t ---

	/**
	* Returns the error scaling factor used by the simplifier to convert between absolute and relative extents
	*
	* Absolute error must be *divided* by the scaling factor before passing it to meshopt_simplify as target_error
	* Relative error returned by meshopt_simplify via result_error must be *multiplied* by the scaling factor to get absolute error.
	*/
	simplifyScale :: proc(vertex_positions: ^f32, vertex_count: c.size_t, vertex_positions_stride: c.size_t) -> f32 ---

	/**
	* Mesh stripifier
	* Converts a previously vertex cache optimized triangle list to triangle strip, stitching strips using restart index or degenerate triangles
	* Returns the number of indices in the resulting strip, with destination containing new index data
	* For maximum efficiency the index buffer being converted has to be optimized for vertex cache first.
	* Using restart indices can result in ~10% smaller index buffers, but on some GPUs restart indices may result in decreased performance.
	*
	* destination must contain enough space for the target index buffer, worst case can be computed with meshopt_stripifyBound
	* restart_index should be 0xffff or 0xffffffff depending on index size, or 0 to use degenerate triangles
	*/
	stripify      :: proc(destination: ^c.uint, indices: ^c.uint, index_count: c.size_t, vertex_count: c.size_t, restart_index: c.uint) -> c.size_t ---
	stripifyBound :: proc(index_count: c.size_t) -> c.size_t ---

	/**
	* Mesh unstripifier
	* Converts a triangle strip to a triangle list
	* Returns the number of indices in the resulting list, with destination containing new index data
	*
	* destination must contain enough space for the target index buffer, worst case can be computed with meshopt_unstripifyBound
	*/
	unstripify      :: proc(destination: ^c.uint, indices: ^c.uint, index_count: c.size_t, restart_index: c.uint) -> c.size_t ---
	unstripifyBound :: proc(index_count: c.size_t) -> c.size_t ---

	/**
	* Vertex transform cache analyzer
	* Returns cache hit statistics using a simplified FIFO model
	* Results may not match actual GPU performance
	*/
	analyzeVertexCache :: proc(indices: ^c.uint, index_count: c.size_t, vertex_count: c.size_t, cache_size: c.uint, warp_size: c.uint, primgroup_size: c.uint) -> Vertex_Cache_Statistics ---

	/**
	* Vertex fetch cache analyzer
	* Returns cache hit statistics using a simplified direct mapped model
	* Results may not match actual GPU performance
	*/
	analyzeVertexFetch :: proc(indices: ^c.uint, index_count: c.size_t, vertex_count: c.size_t, vertex_size: c.size_t) -> Vertex_Fetch_Statistics ---

	/**
	* Overdraw analyzer
	* Returns overdraw statistics using a software rasterizer
	* Results may not match actual GPU performance
	*
	* vertex_positions should have float3 position in the first 12 bytes of each vertex
	*/
	analyzeOverdraw :: proc(indices: ^c.uint, index_count: c.size_t, vertex_positions: ^f32, vertex_count: c.size_t, vertex_positions_stride: c.size_t) -> Overdraw_Statistics ---

	/**
	* Coverage analyzer
	* Returns coverage statistics (ratio of viewport pixels covered from each axis) using a software rasterizer
	*
	* vertex_positions should have float3 position in the first 12 bytes of each vertex
	*/
	analyzeCoverage :: proc(indices: ^c.uint, index_count: c.size_t, vertex_positions: ^f32, vertex_count: c.size_t, vertex_positions_stride: c.size_t) -> Coverage_Statistics ---

	/**
	* Meshlet builder
	* Splits the mesh into a set of meshlets where each meshlet has a micro index buffer indexing into meshlet vertices that refer to the original vertex buffer
	* The resulting data can be used to render meshes using NVidia programmable mesh shading pipeline, or in other cluster-based renderers.
	* When targeting mesh shading hardware, for maximum efficiency meshlets should be further optimized using meshopt_optimizeMeshlet.
	* When using buildMeshlets, vertex positions need to be provided to minimize the size of the resulting clusters.
	* When using buildMeshletsScan, for maximum efficiency the index buffer being converted has to be optimized for vertex cache first.
	*
	* meshlets must contain enough space for all meshlets, worst case size can be computed with meshopt_buildMeshletsBound
	* meshlet_vertices must contain enough space for all meshlets, worst case is index_count elements (*not* vertex_count!)
	* meshlet_triangles must contain enough space for all meshlets, worst case is index_count elements
	* vertex_positions should have float3 position in the first 12 bytes of each vertex
	* max_vertices and max_triangles must not exceed implementation limits (max_vertices <= 256, max_triangles <= 512)
	* cone_weight should be set to 0 when cone culling is not used, and a value between 0 and 1 otherwise to balance between cluster size and cone culling efficiency
	*/
	buildMeshlets      :: proc(meshlets: ^Meshlet, meshlet_vertices: ^c.uint, meshlet_triangles: ^c.uchar, indices: ^c.uint, index_count: c.size_t, vertex_positions: ^f32, vertex_count: c.size_t, vertex_positions_stride: c.size_t, max_vertices: c.size_t, max_triangles: c.size_t, cone_weight: f32) -> c.size_t ---
	buildMeshletsScan  :: proc(meshlets: ^Meshlet, meshlet_vertices: ^c.uint, meshlet_triangles: ^c.uchar, indices: ^c.uint, index_count: c.size_t, vertex_count: c.size_t, max_vertices: c.size_t, max_triangles: c.size_t) -> c.size_t ---
	buildMeshletsBound :: proc(index_count: c.size_t, max_vertices: c.size_t, max_triangles: c.size_t) -> c.size_t ---

	/**
	* Meshlet builder with flexible cluster sizes
	* Splits the mesh into a set of meshlets, similarly to meshopt_buildMeshlets, but allows to specify minimum and maximum number of triangles per meshlet.
	* Clusters between min and max triangle counts are split when the cluster size would have exceeded the expected cluster size by more than split_factor.
	*
	* meshlets must contain enough space for all meshlets, worst case size can be computed with meshopt_buildMeshletsBound using min_triangles (*not* max!)
	* meshlet_vertices must contain enough space for all meshlets, worst case is index_count elements (*not* vertex_count!)
	* meshlet_triangles must contain enough space for all meshlets, worst case is index_count elements
	* vertex_positions should have float3 position in the first 12 bytes of each vertex
	* max_vertices, min_triangles and max_triangles must not exceed implementation limits (max_vertices <= 256, max_triangles <= 512; min_triangles <= max_triangles)
	* cone_weight should be set to 0 when cone culling is not used, and a value between 0 and 1 otherwise to balance between cluster size and cone culling efficiency
	* split_factor should be set to a non-negative value; when greater than 0, clusters that have large bounds may be split unless they are under the min_triangles threshold
	*/
	buildMeshletsFlex :: proc(meshlets: ^Meshlet, meshlet_vertices: ^c.uint, meshlet_triangles: ^c.uchar, indices: ^c.uint, index_count: c.size_t, vertex_positions: ^f32, vertex_count: c.size_t, vertex_positions_stride: c.size_t, max_vertices: c.size_t, min_triangles: c.size_t, max_triangles: c.size_t, cone_weight: f32, split_factor: f32) -> c.size_t ---

	/**
	* Meshlet builder that produces clusters optimized for raytracing
	* Splits the mesh into a set of meshlets, similarly to meshopt_buildMeshlets, but optimizes cluster subdivision for raytracing and allows to specify minimum and maximum number of triangles per meshlet.
	*
	* meshlets must contain enough space for all meshlets, worst case size can be computed with meshopt_buildMeshletsBound using min_triangles (*not* max!)
	* meshlet_vertices must contain enough space for all meshlets, worst case is index_count elements (*not* vertex_count!)
	* meshlet_triangles must contain enough space for all meshlets, worst case is index_count elements
	* vertex_positions should have float3 position in the first 12 bytes of each vertex
	* max_vertices, min_triangles and max_triangles must not exceed implementation limits (max_vertices <= 256, max_triangles <= 512; min_triangles <= max_triangles)
	* fill_weight allows to prioritize clusters that are closer to maximum size at some cost to SAH quality; 0.5 is a safe default
	*/
	buildMeshletsSpatial :: proc(meshlets: ^Meshlet, meshlet_vertices: ^c.uint, meshlet_triangles: ^c.uchar, indices: ^c.uint, index_count: c.size_t, vertex_positions: ^f32, vertex_count: c.size_t, vertex_positions_stride: c.size_t, max_vertices: c.size_t, min_triangles: c.size_t, max_triangles: c.size_t, fill_weight: f32) -> c.size_t ---

	/**
	* Meshlet optimizer
	* Reorders meshlet vertices and triangles to maximize locality to improve rasterizer throughput
	*
	* meshlet_triangles and meshlet_vertices must refer to meshlet triangle and vertex index data; when buildMeshlets* is used, these
	* need to be computed from meshlet's vertex_offset and triangle_offset
	* triangle_count and vertex_count must not exceed implementation limits (vertex_count <= 256, triangle_count <= 512)
	*/
	optimizeMeshlet :: proc(meshlet_vertices: ^c.uint, meshlet_triangles: ^c.uchar, triangle_count: c.size_t, vertex_count: c.size_t) ---

	/**
	* Cluster bounds generator
	* Creates bounding volumes that can be used for frustum, backface and occlusion culling.
	*
	* For backface culling with orthographic projection, use the following formula to reject backfacing clusters:
	*   dot(view, cone_axis) >= cone_cutoff
	*
	* For perspective projection, you can use the formula that needs cone apex in addition to axis & cutoff:
	*   dot(normalize(cone_apex - camera_position), cone_axis) >= cone_cutoff
	*
	* Alternatively, you can use the formula that doesn't need cone apex and uses bounding sphere instead:
	*   dot(normalize(center - camera_position), cone_axis) >= cone_cutoff + radius / length(center - camera_position)
	* or an equivalent formula that doesn't have a singularity at center = camera_position:
	*   dot(center - camera_position, cone_axis) >= cone_cutoff * length(center - camera_position) + radius
	*
	* The formula that uses the apex is slightly more accurate but needs the apex; if you are already using bounding sphere
	* to do frustum/occlusion culling, the formula that doesn't use the apex may be preferable (for derivation see
	* Real-Time Rendering 4th Edition, section 19.3).
	*
	* vertex_positions should have float3 position in the first 12 bytes of each vertex
	* vertex_count should specify the number of vertices in the entire mesh, not cluster or meshlet
	* index_count/3 and triangle_count must not exceed implementation limits (<= 512)
	*/
	computeClusterBounds :: proc(indices: ^c.uint, index_count: c.size_t, vertex_positions: ^f32, vertex_count: c.size_t, vertex_positions_stride: c.size_t) -> Bounds ---
	computeMeshletBounds :: proc(meshlet_vertices: ^c.uint, meshlet_triangles: ^c.uchar, triangle_count: c.size_t, vertex_positions: ^f32, vertex_count: c.size_t, vertex_positions_stride: c.size_t) -> Bounds ---

	/**
	* Sphere bounds generator
	* Creates bounding sphere around a set of points or a set of spheres; returns the center and radius of the sphere, with other fields of the result set to 0.
	*
	* positions should have float3 position in the first 12 bytes of each element
	* radii can be NULL; when it's not NULL, it should have a non-negative float radius in the first 4 bytes of each element
	*/
	computeSphereBounds :: proc(positions: ^f32, count: c.size_t, positions_stride: c.size_t, radii: ^f32, radii_stride: c.size_t) -> Bounds ---

	/**
	* Cluster partitioner
	* Partitions clusters into groups of similar size, prioritizing grouping clusters that share vertices or are close to each other.
	*
	* destination must contain enough space for the resulting partition data (cluster_count elements)
	* destination[i] will contain the partition id for cluster i, with the total number of partitions returned by the function
	* cluster_indices should have the vertex indices referenced by each cluster, stored sequentially
	* cluster_index_counts should have the number of indices in each cluster; sum of all cluster_index_counts must be equal to total_index_count
	* vertex_positions should have float3 position in the first 12 bytes of each vertex (or can be NULL if not used)
	* target_partition_size is a target size for each partition, in clusters; the resulting partitions may be smaller or larger
	*/
	partitionClusters :: proc(destination: ^c.uint, cluster_indices: ^c.uint, total_index_count: c.size_t, cluster_index_counts: ^c.uint, cluster_count: c.size_t, vertex_positions: ^f32, vertex_count: c.size_t, vertex_positions_stride: c.size_t, target_partition_size: c.size_t) -> c.size_t ---

	/**
	* Spatial sorter
	* Generates a remap table that can be used to reorder points for spatial locality.
	* Resulting remap table maps old vertices to new vertices and can be used in meshopt_remapVertexBuffer.
	*
	* destination must contain enough space for the resulting remap table (vertex_count elements)
	* vertex_positions should have float3 position in the first 12 bytes of each vertex
	*/
	spatialSortRemap :: proc(destination: ^c.uint, vertex_positions: ^f32, vertex_count: c.size_t, vertex_positions_stride: c.size_t) ---

	/**
	* Spatial sorter
	* Reorders triangles for spatial locality, and generates a new index buffer. The resulting index buffer can be used with other functions like optimizeVertexCache.
	*
	* destination must contain enough space for the resulting index buffer (index_count elements)
	* vertex_positions should have float3 position in the first 12 bytes of each vertex
	*/
	spatialSortTriangles :: proc(destination: ^c.uint, indices: ^c.uint, index_count: c.size_t, vertex_positions: ^f32, vertex_count: c.size_t, vertex_positions_stride: c.size_t) ---

	/**
	* Spatial clusterizer
	* Reorders points into clusters optimized for spatial locality, and generates a new index buffer.
	* Ensures the output can be split into cluster_size chunks where each chunk has good positional locality. Only the last chunk will be smaller than cluster_size.
	*
	* destination must contain enough space for the resulting index buffer (vertex_count elements)
	* vertex_positions should have float3 position in the first 12 bytes of each vertex
	*/
	spatialClusterPoints :: proc(destination: ^c.uint, vertex_positions: ^f32, vertex_count: c.size_t, vertex_positions_stride: c.size_t, cluster_size: c.size_t) ---

	/**
	* Quantize a float into half-precision (as defined by IEEE-754 fp16) floating point value
	* Generates +-inf for overflow, preserves NaN, flushes denormals to zero, rounds to nearest
	* Representable magnitude range: [6e-5; 65504]
	* Maximum relative reconstruction error: 5e-4
	*/
	quantizeHalf :: proc(v: f32) -> c.ushort ---

	/**
	* Quantize a float into a floating point value with a limited number of significant mantissa bits, preserving the IEEE-754 fp32 binary representation
	* Generates +-inf for overflow, preserves NaN, flushes denormals to zero, rounds to nearest
	* Assumes N is in a valid mantissa precision range, which is 1..23
	*/
	quantizeFloat :: proc(v: f32, N: c.int) -> f32 ---

	/**
	* Reverse quantization of a half-precision (as defined by IEEE-754 fp16) floating point value
	* Preserves Inf/NaN, flushes denormals to zero
	*/
	dequantizeHalf :: proc(h: c.ushort) -> f32 ---

	/**
	* Set allocation callbacks
	* These callbacks will be used instead of the default operator new/operator delete for all temporary allocations in the library.
	* Note that all algorithms only allocate memory for temporary use.
	* allocate/deallocate are always called in a stack-like order - last pointer to be allocated is deallocated first.
	*/
	setAllocator :: proc(allocate: proc "c" (c.size_t) -> rawptr, deallocate: proc "c" (rawptr)) ---
}
