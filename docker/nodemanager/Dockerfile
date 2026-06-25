# =============================================================================
#  ایمیجِ سفارشیِ NodeManager  =  NodeManager استانداردِ Hadoop 2.7.4
#                                 + باینری‌های self-contained .NET (Mapper/Reducer)
#
#  چرا ایمیجِ سفارشی؟  چون تسک‌های Map/Reduce (که Streaming آن‌ها را اجرا می‌کند)
#  *داخلِ کانتینرِ NodeManager* اجرا می‌شوند. با بِیک‌کردنِ باینری‌ها در مسیرِ ثابت
#  و دادنِ بیتِ اجرایی (chmod)، فرمانِ streaming به‌صورتِ
#      -mapper /opt/dotnet-mr/Mapper/Mapper
#  قطعی و بدونِ سربارِ ارسالِ فایل (در مقایسه با -files) اجرا می‌شود.
#
#  پایهٔ ایمیج Debian 9 (glibc 2.24) است؛ به همین دلیل Mapper/Reducer با
#  netcoreapp3.1 منتشر شده‌اند (بالاترین .NET سازگار با این glibc).
#
#  Build context = این پوشه (docker/nodemanager). پوشهٔ bin/ را اسکریپتِ
#  01-build.ps1 با «dotnet publish ... --self-contained» پر می‌کند:
#      bin/Mapper/Mapper      (apphost لینوکسی)
#      bin/Reducer/Reducer
# =============================================================================
FROM bde2020/hadoop-nodemanager:2.0.0-hadoop2.7.4-java8

COPY bin/ /opt/dotnet-mr/

# بیتِ خواندن/اجرا برای همهٔ کاربران (COPY از ویندوز بیتِ اجرایی را حفظ نمی‌کند).
RUN chmod -R a+rX /opt/dotnet-mr && \
    chmod a+rx /opt/dotnet-mr/Mapper/Mapper /opt/dotnet-mr/Reducer/Reducer

# ENTRYPOINT/CMD پایه دست‌نخورده می‌ماند → همان دیمنِ NodeManager اجرا می‌شود.
