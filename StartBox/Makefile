# StartBox/ 子目录 Makefile wrapper
#
# 这个文件让 `make` 在 StartBox/ 子目录里跑也能工作,
# 所有命令会委托到仓库根的主 Makefile。
#
# 实际用法还是推荐在仓库根跑 make,这里只是兜底。

ROOT := $(abspath $(CURDIR)/..)

# 把 PORTABLE=1 之类的参数透传过去
%:
	@$(MAKE) -C $(ROOT) $@ $(MAKEOVERRIDES)

# 默认目标
.DEFAULT:
	@$(MAKE) -C $(ROOT) $@
