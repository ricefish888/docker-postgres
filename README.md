# PostgreSQL (Docker)

[![Analytics](https://ga-beacon.appspot.com/UA-71075299-1/docker-awscli/main-page)](https://github.com/igrigorik/ga-beacon)

### Summary

Alpine based PostgreSQL Docker image with some performance tuning, based on the [official postgres image][postgresdocker].

### Docker image

https://hub.docker.com/r/donbeave/postgres

#### How to use?

In your `Dockerfile` use the following:
```
FROM donbeave/postgres

...
```

Copyright and license
---------------------

Copyright 2017 Alexey Zhokhov under the [Apache License, Version 2.0](LICENSE). Supported by [AZ][zhokhov].

[zhokhov]: http://www.zhokhov.com
[postgresdocker]: https://hub.docker.com/_/postgres/
