//
//  ViewController.m
//  PAMonitor
//
//  Created by 史贵岭 on 2019/4/18.
//  Copyright © 2019年 史贵岭. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()<UITableViewDelegate,UITableViewDataSource>
@property(nonatomic,strong) UITableView *tableView;
@end

@implementation ViewController


- (void) tableInit{
    self.tableView = [[UITableView alloc] initWithFrame:self.view.frame];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.rowHeight = 40;
    [self.view addSubview:self.tableView];
}
- (void)viewDidLoad {
    [super viewDidLoad];
    [self tableInit];
    
    [self.tableView registerClass: [UITableViewCell class] forCellReuseIdentifier: @"cell"];
}

#pragma mark - UITableViewDataSource
- (NSInteger)tableView: (UITableView *)tableView numberOfRowsInSection: (NSInteger)section {
    return 1000;
}

- (UITableViewCell *)tableView: (UITableView *)tableView cellForRowAtIndexPath: (NSIndexPath *)indexPath {
    UITableViewCell * cell = [tableView dequeueReusableCellWithIdentifier: @"cell"];
    cell.textLabel.text = [NSString stringWithFormat: @"%lu", indexPath.row];
    if (indexPath.row > 0 && indexPath.row % 30 == 0) {//模拟处理souce事件源卡顿
        usleep(200000);//0.2秒
    }
    return cell;
}


#pragma mark - UITableViewDelegate
- (void)tableView: (UITableView *)tableView didSelectRowAtIndexPath: (NSIndexPath *)indexPath {
    for (int idx = 0; idx < 100; idx++) {//休眠1秒 模拟Input Source 激活休眠卡顿
        usleep(10000);
    }
}


@end
