# Easy-IP4o6

For the README file written in English, see [README_en.md](README_en.md).

Easy-IP4o6は、Interlinkの[ZOOT NATIVE](https://www.interlink.or.jp/service/zootnative/)等のIPIP（IPv4 over IPv6、IPv6ネットワーク上でIPv4トラフィックを転送）を使った固定IPv4で接続するインターフェイスを提供するパッケージです。IPIPトンネルを提供するパッケージはすでに複数ありますが、設定項目が少なくかんたんに使えることが特徴です。

他社のIPIP接続も設定可能と思いますが、デフォルトの設定値が不明です。そこでデフォルト値を教えてもらえると助かります。

## 機能

- IPIP (IPv4 over IPv6)方式による固定IPv4インターフェイスの作成
- WAN回線の状態に応じたインターフェイスの管理

## 必要な依存関係

- `luci` - Web ベースの設定機能
- `netifd` - OpenWrtのネットワーク管理デーモン
- `kmod-ip6-tunnel` - IPv6トンネルカーネルモジュール

いづれも標準でインストール済みのパッケージで、追加のパッケージは不要です。

ただしマニュアルでのインストールの場合には、下記のパッケージが事前にインストールされている必要があります。

- `openssh-sftp-server` - `scp`によるファイルを受信する
- `make` - 一連のコマンドを自動実行する

## インストール方法

`easy-ip4o6`のインストールは、パッケージを使う方法とマニュアルで実行する方法があります。

### パッケージでインストール

1. パッケージを[Release](https://github.com/nosuz/easy-ip4o6/releases)からダウンロードします。
2. Web管理画面のSystemメニューからSoftwareを選択します。
3. (Optional) `Update Lists...`ボタンを押してパッケージリストを更新します。
4. `Uplocad Package...`ボタンを押して、ダウンロード済みのパッケージをアップロードとインストールします。
5. SystemメニューからRebootを選択して再起動します。

#### パッケージをマニュアルでインストール

```bash
# 依存パッケージをインストールするためにパッケージリストを更新（任意）
opkg update

# パッケージのインストール
opkg install easy-ip4o6_*_all.ipk
reboot
```

### マニュアルでインストール

1. インストールに必要なファイルは全て`easy-ip4o6/files`ディレクトリに入っています。そこで`scp`等で`files`ディレクトリをまるごとOpenWrtマシンにコピーします。

2. OpenWrtマシンに`ssh`または`slogin`でログインし、コピーした`files`に移動し、`make install`を実行するとファイルがインストールされます。インストールした設定が認識されない場合は、再起動してください。

```bash
# copy files. `openssh-sftp-server` package is required on OpenWrt machine.
scp -r easy-ip4o6/files root@<OpenWrt Address>:
```

```bash
# install files. `make` package is required on OpenWrt machine.
cd files
make install
# `make remove` to uninstall files.
reboot
```

マニュアルでインストールした`easy-ip4o6`を削除するには、`make remove`を実行します。

## 使用方法

1. Web管理画面のNetworkメニューからInterfacesを選択します。
2. `Add new interface...`ボタンを押して、インターフェイス名を入力します。Protocolは、`Easy IPv4 over IPv6 (ip4o6)`を選択します。
3. Tunneling ServiceからISPのサービス名を選択します。今の所InterlinkのZOOT NATIVE以外は、`Other`を選んでください。
4. Peer IPv6 Addressには、ISPから提供された終端装置のIPv6アドレス(ISP側)を入力します。
5. Fixed global IPv4 Addressには、ISPから割り当てたれた固定IPv4アドレスを入力します。
6. 必要に応じてLocal IPv6 Interface(IPv6の下位64ビット)とMTUの値を入力します。
7. `Firewall Settings`から適切な`firewall-zone`（例えば`wan`）を選択します。
8. `Save & Apply`ボタンを押して、設定を保存してネットワークを再起動します。

アップデートサーバにIPv6アドレスを通知する機能を`easy-ip4o6`では省略しています。IPv6アドレスを通知することで再接続の時間が短くなるという説明がありますが、必要を感じたことはありません。

### トラブルシューティング

- Protocolい`Easy IPv4 over IPv6 (ip4o6)`が現れない時は、再起動してみてください。
- 通信できるサイトとできないサイトがある場合は、MTUの値を小さくしてみてください。

## ファイル構成

```
Makefile                          # パッケージ作成用Makefile
easy-ip4o6/
├── Makefile                   # OpenWrtビルドシステム用Makefile
└── files/
    ├── Makefile               # 手動でのインストール用Makefile
    ├── ip4o6.js               # LuCIハンドラ
    ├── ip4o6.sh               # netifdプロトコルハンドラ
    └── 99-ip4o6-control       # ホットプラグイベントハンドラ
```

## 開発環境のセットアップ

パッケージのビルドには、OpenWrtが提供する[Docker Image](https://hub.docker.com/r/openwrt/sdk)を使用します。

参考: [GitHub - openwrt/docker: Docker containers of the ImageBuilder and SDK](https://github.com/openwrt/docker)

### Dev Containerの使用

このプロジェクトはOpenWrtのDockerコンテナをDev Containerとして使用した開発環境をサポートしています。Dev Containerを起動する手順は次のとおりです。

1. このプロジェクトをVSCodeで開きます。
2. `Ctrl + Shift + P`でコマンドパレットを開きます。
3. `Dev Containers: Rebuild and Reopen in Container`を選択します。最新のfeedを取得してインストールするため**初回の起動時は30分近くかかることがあります**。

#### トラブルティーティング

ユーザIDの問題では`permission error`が発生する時は、`.devcontainer/generate_env.py`または`.devcontainer/generate_env.sh`を実行して、`.devcontainer/.env`にあなたのユーザIDとグループIDを設定して、再度コンテナをビルドしてください。

## パッケージのビルド

```bash
# Dev Container内で実行
# 注意: 初回起動時は以下のコマンドが実行され、完了まで最大30分かかる場合があります
# if [ -d openwrt ]; then cd openwrt; else mkdir openwrt && cd openwrt && /builder/setup.sh; fi && ./scripts/feeds update -a && ./scripts/feeds install -a

# パッケージ管理の作成
# このコンテナはx86_64用パッケージをビルドします
make build
```

`make build`を実行すると、内部で`make menuconfig`が実行されます。Networkから`easy-ip4o6`パッケージが作成されるように選択(Mマーク)してください。その後自動的にビルドプロセスが起動されます。

作成されたパッケージは、トップディレクトリにコピーされます。

## ライセンス

GPL-2.0

## メンテナ

[@nosuz123](https://x.com/nosuz123) on X

## 貢献

バグレポートや機能要求は、GitHubのIssueで受け付けています。プルリクエストも歓迎します。
