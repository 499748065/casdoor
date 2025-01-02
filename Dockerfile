FROM --platform=$BUILDPLATFORM node:18.19.0 AS FRONT
WORKDIR /web
COPY ./web .
RUN yarn install --frozen-lockfile --network-timeout 1000000 && yarn run build

FROM --platform=$BUILDPLATFORM golang:1.20.12 AS BACK
WORKDIR /go/src/casdoor
COPY . .
RUN ./build.sh
RUN go test -v -run TestGetVersionInfo ./util/system_test.go ./util/system.go > version_info.txt

FROM debian:bullseye-slim
LABEL MAINTAINER="https://casdoor.org/"

# 安装必要的系统组件
RUN apt-get update && apt-get install -y \
    ca-certificates \
    tzdata \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 设置工作目录
WORKDIR /app

# 从构建阶段复制文件
COPY --from=BACK /go/src/casdoor/server_linux_amd64 ./server
COPY --from=BACK /go/src/casdoor/swagger ./swagger
COPY --from=BACK /go/src/casdoor/conf/app.conf ./conf/app.conf
COPY --from=BACK /go/src/casdoor/version_info.txt ./version_info.txt
COPY --from=FRONT /web/build ./web/build

# 暴露端口
EXPOSE 8000

# 设置环境变量
ENV TZ=Asia/Shanghai

# 启动命令
CMD ["/app/server"]
