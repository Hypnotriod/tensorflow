# TensorFlow SavedModel

[TOC]

## Overview

SavedModel is the universal serialization format for
[TensorFlow](https://www.tensorflow.org/) models.

SavedModel provides a language-neutral format to save machine-learning models
that is recoverable and hermetic. It enables higher-level systems and tools to
produce, consume and transform TensorFlow models.

## Guides
* [Using the SavedModel Format](https://www.tensorflow.org/guide/saved_model)
* [Save and load Keras models](https://www.tensorflow.org/guide/keras/save_and_serialize)
* [Save and load with checkpointing in Keras](https://www.tensorflow.org/tutorials/keras/save_and_load)
* [Training checkpoints](https://www.tensorflow.org/guide/checkpoint)
* [Save and load a model using a distribution strategy](https://www.tensorflow.org/tutorials/distribute/save_and_load)


## [Public API](https://www.tensorflow.org/api_docs/python/tf/saved_model)
* [`tf.saved_model.save`](https://www.tensorflow.org/api_docs/python/tf/saved_model/save)
* [`tf.saved_model.load`](https://www.tensorflow.org/api_docs/python/tf/saved_model/load)
* [`tf.saved_model.SaveOptions`](https://www.tensorflow.org/api_docs/python/tf/saved_model/SaveOptions)
* [`tf.saved_model.LoadOptions`](https://www.tensorflow.org/api_docs/python/tf/saved_model/LoadOptions)
* [`tf.saved_model.Asset`](https://www.tensorflow.org/api_docs/python/tf/saved_model/Asset)
* [`tf.saved_model.contains_saved_model`](https://www.tensorflow.org/api_docs/python/tf/saved_model/contains_saved_model)

### Related Modules and Functions
* [`tf.keras.models.save_model`](https://www.tensorflow.org/api_docs/python/tf/keras/models/save_model)
* [`tf.keras.models.load_model`](https://www.tensorflow.org/api_docs/python/tf/keras/models/load_model)
* [`tf.train.Checkpoint`](https://www.tensorflow.org/api_docs/python/tf/train/Checkpoint)


## The SavedModel Format
A SavedModel directory has the following structure:

```
assets/
assets.extra/
variables/
    variables.data-?????-of-?????
    variables.index
saved_model.pb
```

*   SavedModel protocol buffer
    *   [`saved_model.pb`](https://github.com/galeone/tensorflow/blob/master/tensorflow/core/protobuf/saved_model.proto)
        or `saved_model.pbtxt`
    *   Includes the graph definitions as `MetaGraphDef` protocol buffers.
*   Assets
    *   Subfolder called `assets`.
    *   Contains auxiliary files such as vocabularies, etc.
*   Extra assets
    *   Subfolder where higher-level libraries and users can add their own
        assets that co-exist with the model, but are not loaded by the graph.
    *   This subfolder is not managed by the SavedModel libraries.
*   Variables
    *   Subfolder called `variables`.
        *   `variables.data-?????-of-?????`
        *   `variables.index`

---

## SavedModel in TensorFlow 1.x

SavedModel had slightly different semantics in TF 1.x. Conventions that are
generally only supported in TF 1.x are noted as such.

### Features

The following is a summary of the features in SavedModel:

* (TF1-only) Multiple graphs sharing a single set of variables and assets can be added to a
  single SavedModel. Each graph is associated with a specific set of tags to
  allow identification during a load or restore operation.
* (TF1-only) Support for `SignatureDefs`
    * Graphs that are used for inference tasks typically have a set of inputs
      and outputs. This is called a `Signature`.
    * SavedModel uses [SignatureDefs](https://github.com/galeone/tensorflow/blob/master/tensorflow/core/protobuf/meta_graph.proto)
      to allow generic support for signatures that may need to be saved with the graphs.
    * For commonly used SignatureDefs in the context of TensorFlow Serving,
      please see documentation [here](https://github.com/tensorflow/serving/blob/master/tensorflow_serving/g3doc/signature_defs.md).
* Support for `Assets`.
    * For cases where ops depend on external files for initialization, such as
      vocabularies, SavedModel supports this via `assets`.
    * Assets are copied to the SavedModel location and can be read when loading
      a specific meta graph def.
* Support to clear devices before generating the SavedModel.

The following is a summary of features that are NOT supported in SavedModel.
Higher-level frameworks and tools that use SavedModel may provide these.

* Implicit versioning.
* Garbage collection.
* Atomic writes to the SavedModel location.

### TF1 SavedModel Background
SavedModel manages and builds upon existing TensorFlow primitives such as
`TensorFlow Saver` and `MetaGraphDef`. Specifically, SavedModel wraps a [TensorFlow Saver](https://github.com/galeone/tensorflow/tree/master/tensorflow/python/training/saver.py).
The Saver is primarily used to generate the variable checkpoints. SavedModel
will replace the existing [TensorFlow Inference Model Format](https://github.com/galeone/tensorflow/tree/r1.15/tensorflow/contrib/session_bundle#tensorflow-inference-model-format)
as the canonical way to export TensorFlow graphs for serving.


### APIs
The APIs for building and loading a SavedModel are described in this section.

#### (TF1-only) Builder
The SavedModel [builder](https://github.com/galeone/tensorflow/blob/master/tensorflow/python/saved_model/builder.py)
is implemented in Python.

The `SavedModelBuilder` class provides functionality to save multiple meta graph
defs, associated variables and assets.

To build a SavedModel, the first meta graph must be saved with variables.
Subsequent meta graphs will simply be saved with their graph definitions. If
assets need to be saved and written or copied to disk, they can be provided
when the meta graph def is added. If multiple meta graph defs are associated
with an asset of the same name, only the first version is retained.

#### (TF1-only) Tags
Each meta graph added to the SavedModel must be annotated with user specified
tags, which reflect the meta graph capabilities or use-cases.
More specifically, these tags typically annotate a meta graph with its
functionality (e.g. serving or training), and possibly hardware specific aspects
such as GPU.
In the SavedModel, the meta graph def whose tag-set exactly matches those
specified in the loader API, will be the one loaded by the loader.
If no meta graph def is found matching the specified tags, an error is returned.
For example, a loader with a requirement to serve on GPU hardware would be able
to load only meta graph annotated with tags='serve,gpu' by specifying this set
of tags in tensorflow::LoadSavedModel(...).


#### Usage
The typical usage of `builder` is as follows:

~~~python
export_dir = ...
...
builder = tf.saved_model.builder.SavedModelBuilder(export_dir)
with tf.Session(graph=tf.Graph()) as sess:
  ...
  builder.add_meta_graph_and_variables(sess,
                                       [tf.saved_model.tag_constants.TRAINING],
                                       signature_def_map=foo_signatures,
                                       assets_collection=foo_assets)
...
with tf.Session(graph=tf.Graph()) as sess:
  ...
  builder.add_meta_graph(["bar-tag", "baz-tag"])
...
builder.save()
~~~

#### (TF1-only) Stripping Default valued attributes
The SavedModelBuilder class allows users to control whether default-valued
attributes must be stripped from the NodeDefs while adding a meta graph to the
SavedModel bundle. Both `SavedModelBuilder.add_meta_graph_and_variables` and
`SavedModelBuilder.add_meta_graph` methods accept a Boolean flag
`strip_default_attrs` that controls this behavior.

If `strip_default_attrs` is `False`, the exported MetaGraphDef will have the
default valued attributes in all it's NodeDef instances. This can break forward
compatibility with a sequence of events such as the following:

* An existing Op (`Foo`) is updated to include a new attribute (`T`) with a
  default (`bool`) at version 101.
* A model producer (such as a Trainer) binary picks up this change
  (version 101) to the OpDef and re-exports an existing model that uses Op `Foo`.
* A model consumer (such as Tensorflow Serving) running an older binary
  (version 100) doesn't have attribute `T` for Op `Foo`, but tries to import
  this model. The model consumer doesn't recognize attribute `T` in a NodeDef
  that uses Op `Foo` and therefore fails to load the model.

By setting `strip_default_attrs` to `True`, the model producers can strip away
any default valued attributes in the NodeDefs. This helps ensure that newly
added attributes with defaults don't cause older model consumers to fail loading
models regenerated with newer training binaries.

TIP: If you care about forward compatibility, then set `strip_default_attrs`
to `True` while using `SavedModelBuilder.add_meta_graph_and_variables` and
`SavedModelBuilder.add_meta_graph`.

### Loader
The SavedModel loader is implemented in C++ and Python.

#### (TF1-only) Python
The Python version of the SavedModel [loader](https://github.com/galeone/tensorflow/blob/master/tensorflow/python/saved_model/loader.py)
provides load and restore capability for a SavedModel. The `load` operation
requires the session in which to restore the graph definition and variables, the
tags used to identify the meta graph def to load and the location of the
SavedModel. Upon a load, the subset of variables and assets supplied as part of
the specific meta graph def, will be restored into the supplied session.

~~~python
export_dir = ...
...
with tf.Session(graph=tf.Graph()) as sess:
  tf.saved_model.loader.load(sess, [tag_constants.TRAINING], export_dir)
  ...
~~~

#### C++
The C++ version of the SavedModel [loader](https://github.com/galeone/tensorflow/blob/master/tensorflow/cc/saved_model/loader.h)
provides an API to load a SavedModel from a path, while allowing
`SessionOptions` and `RunOptions`. Similar to the Python version, the C++
version requires the tags associated with the graph to be loaded, to be
specified. The loaded version of SavedModel is referred to as `SavedModelBundle`
and contains the meta graph def and the session within which it is loaded.

~~~c++
const string export_dir = ...
SavedModelBundle bundle;
...
LoadSavedModel(session_options, run_options, export_dir, {kSavedModelTagTrain},
               &bundle);
~~~

### Constants
SavedModel offers the flexibility to build and load TensorFlow graphs for a
variety of use-cases. For the set of most common expected use-cases,
SavedModel's APIs provide a set of constants in Python and C++ that are easy to
reuse and share across tools consistently.

#### (TF1-specific) Tag constants
Sets of tags can be used to uniquely identify a `MetaGraphDef` saved in a
SavedModel. A subset of commonly used tags is specified in:

* [Python](https://github.com/galeone/tensorflow/blob/master/tensorflow/python/saved_model/tag_constants.py)
* [C++](https://github.com/galeone/tensorflow/blob/master/tensorflow/cc/saved_model/tag_constants.h).

#### (TF1-specific) Signature constants
SignatureDefs are used to define the signature of a computation supported in a
TensorFlow graph. Commonly used input keys, output keys and method names are
defined in:

* [Python](https://github.com/galeone/tensorflow/blob/master/tensorflow/python/saved_model/signature_constants.py)
* [C++](https://github.com/galeone/tensorflow/blob/master/tensorflow/cc/saved_model/signature_constants.h).
