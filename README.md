# Build Systems à la Carte

[![Linux & OS X status](https://img.shields.io/travis/snowleopard/build/master.svg?label=Linux%20%26%20OS%20X)](https://travis-ci.org/snowleopard/build) [![Windows status](https://img.shields.io/appveyor/ci/snowleopard/build/master.svg?label=Windows)](https://ci.appveyor.com/project/snowleopard/build)

Build systems are awesome, terrifying -- and unloved.
They power developers around the world, but are rarely the object of study.
This project provides an executable framework for developing and comparing
build systems, viewing them as related points in landscape rather than as isolated phenomena.
By teasing apart existing build systems,
[we can recombine their components](https://github.com/snowleopard/build/blob/master/src/Build/System.hs),
allowing us to prototype the first build system that combines dynamic dependencies and cloud builds.

----

This paper provides a detailed introduction to this project:
[[PDF](https://github.com/snowleopard/build-systems/releases/download/icfp-submission/build-systems.pdf),
[sources](https://github.com/snowleopard/build-systems/tree/master/paper)].

Also have a look at [this blog post](https://blogs.ncl.ac.uk/andreymokhov/the-task-abstraction/)
about the abstraction we use to model build tasks.

To learn more about the initial motivation behind the project, read
[this earlier blog post](https://blogs.ncl.ac.uk/andreymokhov/cloud-and-dynamic-builds/).
