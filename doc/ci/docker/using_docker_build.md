# Using Docker Build

GitLab CI allows you to use Docker Engine to build and test docker-based projects.

**This also allows to you to use `docker-compose` and other docker-enabled tools.**

This is one of new trends in Continuous Integration/Deployment to:

1. create application image,
1. run test against created image,
1. push image to remote registry,
1. deploy server from pushed image

It's also useful in case when your application already has the `Dockerfile` that can be used to create and test image:
```bash
$ docker build -t my-image dockerfiles/
$ docker run my-docker-image /script/to/run/tests
$ docker tag my-image my-registry:5000/my-image
$ docker push my-registry:5000/my-image
```

However, this requires special configuration of GitLab Runner to enable `docker` support during build.
**This requires running GitLab Runner in privileged mode which can be harmful when untrusted code is run.**

There are two methods to enable the use of `docker build` and `docker run` during build.

## 1. Use shell executor

The simplest approach is to install GitLab Runner in `shell` execution mode.
GitLab Runner then executes build scripts as `gitlab-runner` user.

1. Install [GitLab Runner](https://gitlab.com/gitlab-org/gitlab-ci-multi-runner/#installation).

1. During GitLab Runner installation select `shell` as method of executing build scripts or use command:

    ```bash
    $ sudo gitlab-runner register -n \
      --url https://gitlab.com/ci \
      --token RUNNER_TOKEN \
      --executor shell
      --description "My Runner"
    ```

2. Install Docker Engine on server.

    For more information how to install Docker Engine on different systems checkout the [Supported installations](https://docs.docker.com/engine/installation/).

3. Add `gitlab-runner` user to `docker` group:

    ```bash
    $ sudo usermod -aG docker gitlab-runner
    ```

4. Verify that `gitlab-runner` has access to Docker:

    ```bash
    $ sudo -u gitlab-runner -H docker info
    ```

    You can now verify that everything works by adding `docker info` to `.gitlab-ci.yml`:
    ```yaml
    before_script:
      - docker info

    build_image:
      script:
        - docker build -t my-docker-image .
        - docker run my-docker-image /script/to/run/tests
    ```

5. You can now use `docker` command and install `docker-compose` if needed.

6. However, by adding `gitlab-runner` to `docker` group you are effectively granting `gitlab-runner` full root permissions.
For more information please checkout [On Docker security: `docker` group considered harmful](https://www.andreas-jung.com/contents/on-docker-security-docker-group-considered-harmful).

## 2. Use docker-in-docker executor

The second approach is to use the special Docker image with all tools installed
(`docker` and `docker-compose`) and run the build script in context of that
image in privileged mode.

In order to do that follow the steps:

1. Install [GitLab Runner](https://gitlab.com/gitlab-org/gitlab-ci-multi-runner/#installation).

1. Register GitLab Runner from the command line to use `docker` and `privileged`
   mode:

    ```bash
    sudo gitlab-runner register -n \
      --url https://gitlab.com/ci \
      --token RUNNER_TOKEN \
      --executor docker \
      --description "My Docker Runner" \
      --docker-image "docker:latest" \
      --docker-privileged
    ```

    The above command will register a new Runner to use the special
    `docker:latest` image which is provided by Docker. **Notice that it's using
    the `privileged` mode to start the build and service containers.** If you
    want to use [docker-in-docker] mode, you always have to use `privileged = true`
    in your Docker containers.

    The above command will create a `config.toml` entry similar to this:

    ```
    [[runners]]
      url = "https://gitlab.com/ci"
      token = TOKEN
      executor = "docker"
      [runners.docker]
        tls_verify = false
        image = "docker:latest"
        privileged = true
        disable_cache = false
        volumes = ["/cache"]
      [runners.cache]
        Insecure = false
    ```

    If you want to use the Shared Runners available on your GitLab CE/EE
    installation in order to build Docker images, then make sure that your
    Shared Runners configuration has the `privileged` mode set to `true`.

1. You can now use `docker` from build script:

    ```yaml
    image: docker:latest

    services:
    - docker:dind

    before_script:
    - docker info

    build:
      stage: build
      script:
      - docker build -t my-docker-image .
      - docker run my-docker-image /script/to/run/tests
    ```

1. However, by enabling `--docker-privileged` you are effectively disabling all
   the security mechanisms of containers and exposing your host to privilege
   escalation which can lead to container breakout.

   For more information, check out the official Docker documentation on
   [Runtime privilege and Linux capabilities][docker-cap].

An example project using this approach can be found here: https://gitlab.com/gitlab-examples/docker.

[docker-in-docker]: https://blog.docker.com/2013/09/docker-can-now-run-within-docker/
[docker-cap]: https://docs.docker.com/engine/reference/run/#runtime-privilege-and-linux-capabilities
